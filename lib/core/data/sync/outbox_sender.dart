import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../domain/account.dart';
import '../../domain/attachment_repository.dart';
import '../../domain/error_log.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/outbox_repository.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../../domain/send_limit.dart';
import '../daos/outbox_dao.dart';
import '../mime.dart';

/// Annulla invio: how long after Invia the message can still be taken back (#36).
const sendWindow = Duration(seconds: 10);

/// How long a replay owns an outbox row it is sending, against the other isolate (#36).
/// It must outlast the adapter's worst case: 5 retries x <=32 s backoff + 6 x 30 s stall ~ 6 min; 10 min is the margin.
// ponytail: a crash mid-send delays the retry by the lease; renew the claim during the send if that ever hurts.
const sendClaim = Duration(minutes: 10);

/// The outbox of the sync engine (#36): Invia queues the message and starts its Annulla window, [sendDue] sends
/// what is due. No queue of its own (ADR 0008): the window's ticker calls back `flushOutbox`, the engine's method,
/// so every send runs inside the Account's serial queue; [sendDue] is called only from there.
class OutboxSender(
  final OutboxRepository _outbox,
  final Clock _clock,
  final BackgroundSender _background,
  final ErrorLog _log, {
  required final Future<Account?> Function(String accountId) _account,
  required final Future<void> Function(String accountId) _flushOutbox,

  /// The Provider rate-limited the Account: no sync nor send before the deadline.
  required final void Function(String accountId, DateTime until) _pause,
}) {
  /// `account` looks the Account up; `flushOutbox` is the engine's, queued in the Account's serial slot;
  /// `pause` tells the engine the Provider rate-limited the Account.
  this;

  /// Accounts the platform is holding for (#36); released once their outbox is empty.
  /// A hold made by a previous run of the app is not here: the platform drops it on its own.
  final _held = <String>{};

  /// Per (Account, Message-ID), the one-shot ticker that sends the message once its window ends.
  final _sendTimers = <(String, String), StreamSubscription<void>>{};

  Future<void> stop() async {
    await Future.wait([for (final s in _sendTimers.values) s.cancel()]);
    _sendTimers.clear();
  }

  Future<Result<DateTime>> send(String accountId, OutgoingMessage message) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    // A second Invia of the same Message-ID (a reopened composer): the first one stands, unless it failed preparing.
    var existing = await _outbox.outgoing(accountId, message.messageId);
    if (existing != null && existing.failed) {
      await _outbox.dropOutgoing(accountId, message.messageId, existing.version);
      existing = null;
    }
    if (existing != null) {
      return existing.sendAfter == OutboxDao.preparing
          ? const Err(UnexpectedFailure('already preparing'))
          : Ok(DateTime.fromMillisecondsSinceEpoch(existing.sendAfter));
    }
    // Tags this preparation; random so it is unique across isolates too (collision odds 2^-31 per Message-ID).
    final version = Random.secure().nextInt(1 << 31);
    // The row is born now, without MIME: Bozze hides it, Inviati shows it and Annulla works while it is prepared.
    await _outbox.enqueueOutgoing(accountId, message, version: version, raw: '', sendAfter: OutboxDao.preparing);
    // The platform keeps the preparation and the send going if the user leaves now (a slow attachment download
    // would otherwise leave the row preparing); a refusal never fails the Invia. Held at every Invia: the platform
    // renews its protection (iOS replaces a task its expiration handler may have ended, Android appends work);
    // _held only tells _releaseIfEmpty that a release is due.
    _held.add(accountId);
    unawaited(
      _background.hold(accountId).catchError((Object e) {
        debugPrint('[sync] $accountId: background hold failed, $e');
      }),
    );
    // A forward's attachments are read now, from the cache (offline too) or the Provider, so the queued text is complete.
    // ponytail: an attachment never opened here needs the network at Invia (OfflineFailure); persist copies of the
    // attachments when the forward is composed to queue those offline too.
    final String raw;
    switch (await renderMimeFetching(
      message,
      _clock.now(),
      (messageId, attachmentId) => GetIt.I<AttachmentRepository>().bytes(accountId, messageId, attachmentId),
    )) {
      case Ok(:final value):
        raw = value;
      case Err(:final failure):
        _log.failure('send $accountId', failure);
        await _outbox.outgoingFailed(accountId, message.messageId, version: version);
        await _releaseIfEmpty(accountId);
        return Err(failure);
    }
    // The Provider's limit; IMAP/SMTP has none here: the server's SIZE refuses it at submission.
    if (sendLimitBytes(account.provider) case final limit? when raw.length > limit) {
      _log.failure('send $accountId', SizeLimitFailure(limit));
      await _outbox.outgoingFailed(accountId, message.messageId, version: version);
      await _releaseIfEmpty(accountId);
      return Err(SizeLimitFailure(limit));
    }
    // The window starts once the MIME is ready: a slow download never eats the user's Annulla time.
    final sendAfter = _clock.now().add(sendWindow);
    if (!await _outbox.outgoingReady(
      accountId,
      message.messageId,
      version: version,
      raw: raw,
      sendAfter: sendAfter.millisecondsSinceEpoch,
    )) {
      // Cancelled, or replaced by a newer Invia: this preparation is obsolete and leaves the row alone.
      await _releaseIfEmpty(accountId);
      return const Err(CancelledFailure());
    }
    final key = (accountId, message.messageId);
    await _sendTimers.remove(key)?.cancel();
    _sendTimers[key] = _clock.every(sendWindow).listen((_) {
      unawaited(_sendTimers.remove(key)?.cancel());
      unawaited(_flushOutbox(accountId));
    });
    return Ok(sendAfter);
  }

  Future<String?> cancelSend(String accountId, String messageId) async {
    await _sendTimers.remove((accountId, messageId))?.cancel();
    final item = await _outbox.outgoing(accountId, messageId);
    // SMTP already delivered it (#175): only the copy in Inviati is left, which the replay finishes; no edit to resend.
    if (item != null && item.submitted) return null;
    final attempted = item?.attempted ?? false;
    // Not behind the Account's queue: a replay waiting on a slow upload would send the row first.
    // The claim in the database refuses the cancel of a row that is going now (false).
    final cancelled = await _outbox.cancelOutgoing(accountId, messageId, _clock.now().millisecondsSinceEpoch);
    await _releaseIfEmpty(accountId);
    if (!cancelled) return null;
    final account = attempted ? await _account(accountId) : null;
    if (account == null) return messageId;
    // ponytail: the original may or may not have been delivered; a new Message-ID keeps the two apart (an edit is never
    // taken for the original), and the next sync shows the original in Inviati if it went. The old remote draft is left to reconcile.
    final fresh = newMessageId(account.address);
    return await _outbox.rekeyDraft(accountId, messageId, fresh) ? fresh : messageId;
  }

  /// Sends the Account's outbox entries whose window has ended: so a restart, a poll and the reconnection all send
  /// what is due. The 10 s ticker and the WorkManager isolate reach here through the engine's flushOutbox.
  /// Called only from inside the Account's serial queue.
  Future<void> sendDue(String accountId, MailProvider provider) async {
    final now = _clock.now().millisecondsSinceEpoch;
    outbox:
    for (final row in await _outbox.dueOutgoing(accountId, now)) {
      // Taken in the database first: the WorkManager isolate may be replaying the same row; the loser skips it.
      // ponytail: a crash mid-send keeps the row claimed, so its retry waits up to [sendClaim].
      // A fresh clock reading: earlier sends in this loop may have been slow.
      final claimAt = _clock.now().millisecondsSinceEpoch;
      if (!await _outbox.claimOutgoing(
        accountId,
        row.messageId,
        sendAfter: row.sendAfter,
        untilMs: claimAt + sendClaim.inMilliseconds,
        nowMs: claimAt,
      )) {
        continue;
      }
      // Read after the claim: the batch snapshot may predate another isolate's submission of this row (#175).
      final submitted = (await _outbox.outgoing(accountId, row.messageId))?.submitted ?? row.submitted;
      final result = await provider.send(
        row.messageId,
        row.raw,
        threadId: row.conversationId,
        submitted: submitted,
        onSubmitted: () =>
            _outbox.outgoingSubmitted(accountId, row.messageId, nowMs: _clock.now().millisecondsSinceEpoch),
      );
      // Delivered by SMTP before or during this attempt (#175).
      final delivered =
          submitted || (result is Err && (await _outbox.outgoing(accountId, row.messageId))?.submitted == true);
      switch (result) {
        case Ok(:final value):
          await _outbox.outgoingSent(accountId, row.messageId, providerId: value, date: now, sendAfter: row.sendAfter);
          debugPrint('[sync] $accountId: sent ${row.messageId}');
        // SMTP delivered it and only the copy in Inviati is refused: not failed (a retry by the user would send it
        // twice); the next sync shows the Provider's copy, if any.
        case Err(failure: SizeLimitFailure() || NotFoundFailure() || RejectedFailure()) when delivered:
          await _outbox.outgoingSent(
            accountId,
            row.messageId,
            providerId: row.messageId,
            date: now,
            sendAfter: row.sendAfter,
          );
          debugPrint('[sync] $accountId: sent ${row.messageId}, copy in Inviati refused');
        // Refused for good (too big, Bozza gone): kept as failed for the UI, never retried (ADR 0008).
        case Err(failure: final f && (SizeLimitFailure() || NotFoundFailure() || RejectedFailure())):
          await _outbox.outgoingFailed(accountId, row.messageId);
          debugPrint('[sync] $accountId: send refused ${row.messageId}, $f');
          _log.failure('send $accountId', f);
        // Rate limited: the Account waits for the deadline, as after a sync; the rest stays queued.
        case Err(failure: final f && RateLimitFailure(:final retryAfter?)):
          _log.failure('send $accountId', f);
          _pause(accountId, retryAfter);
          await _outbox.unclaimOutgoing(accountId, row.messageId);
          debugPrint('[sync] $accountId: send paused until $retryAfter');
          break outbox;
        case Err(:final failure):
          await _outbox.unclaimOutgoing(accountId, row.messageId);
          debugPrint('[sync] $accountId: send failed, $failure');
          _log.failure('send $accountId', failure);
      }
    }
    await _releaseIfEmpty(accountId);
  }

  /// Lets the platform go once nothing of the Account is queued any more.
  Future<void> _releaseIfEmpty(String accountId) async {
    if (!_held.contains(accountId) || await _outbox.hasOutgoing(accountId)) {
      return;
    }
    _held.remove(accountId);
    try {
      await _background.release(accountId);
    } on Object catch (e) {
      debugPrint('[sync] $accountId: background release failed, $e');
    }
  }
}
