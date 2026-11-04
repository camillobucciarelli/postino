import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/attachment_repository.dart';
import '../domain/html_text.dart';
import '../domain/mail_provider.dart';
import '../domain/mail_sync.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'daos/outbox_dao.dart';
import 'gmail/gmail_provider.dart';
import 'mail_store.dart';
import 'mime.dart';

/// Polling period: the change signal watches only the inbox, so the poll also brings Bozze and the rest (ADR 0008).
const pollEvery = Duration(seconds: 60);

/// Pause in the edits after which a Bozza goes to the Provider (#35).
const draftDebounce = Duration(seconds: 5);

/// Annulla invio: how long after Invia the message can still be taken back (#36).
const sendWindow = Duration(seconds: 10);

/// How long a replay owns an outbox row it is sending, against the other isolate (#36).
/// It must outlast the adapter's worst case: 5 retries x <=32 s backoff + 6 x 30 s stall ~ 6 min; 10 min is the margin.
// ponytail: a crash mid-send delays the retry by the lease; renew the claim during the send if that ever hurts.
const sendClaim = Duration(minutes: 10);

/// Sync engine (ADR 0008): initial sync once per Account, then incremental from the saved cursor
/// whenever the change signal fires, every [pollEvery], and when the network returns.
@lazySingleton
class SyncEngine implements MailSync {
  SyncEngine(this._store, this._clock, this._connectivity, this._background);
  final MailStore _store;
  final Clock _clock;
  final Connectivity _connectivity;
  final BackgroundSender _background;

  /// Accounts the platform is holding for (#36); released once their outbox is empty.
  /// A hold made by a previous run of the app is not here: the platform drops it on its own.
  final _held = <String>{};

  final _subs = <StreamSubscription<Object?>>[];
  final _signals = <String, StreamSubscription<ChangeSignal>>{};

  /// Accounts the Provider blocked until a given time: no sync before it.
  final _pausedUntil = <String, DateTime>{};

  /// Per Account, the tail of its serial queue: syncs, Conversazione hydrations and replays
  /// run one after the other, so none applies a Provider answer older than one already applied.
  final _tail = <String, Future<void>>{};

  /// Per Account, the sync waiting in the queue: more requests join it instead of piling up.
  final _queuedSync = <String, Future<void>>{};

  /// Per Account, the ticker that sends its Bozze once the edits pause.
  final _draftTimers = <String, StreamSubscription<void>>{};

  /// Per (Account, Message-ID), the one-shot ticker that sends the message once its window ends.
  final _sendTimers = <(String, String), StreamSubscription<void>>{};

  /// Starts listening to change signals, the poll and the network, then syncs everything.
  void start() {
    _subs
      ..add(_store.watchAccounts().listen(_watchSignals))
      ..add(_clock.every(pollEvery).listen((_) => _poll()))
      ..add(
        _connectivity.onChanged.listen((online) {
          if (online) unawaited(syncAll());
        }),
      );
    unawaited(syncAll());
  }

  Future<void> stop() async {
    await Future.wait([
      for (final s in [
        ..._subs,
        ..._signals.values,
        ..._draftTimers.values,
        ..._sendTimers.values,
      ])
        s.cancel(),
    ]);
    _subs.clear();
    _signals.clear();
    _draftTimers.clear();
    _sendTimers.clear();
  }

  @override
  Future<void> syncAll() async {
    // On resume the WorkManager isolate may have sent (or refused) outbox rows: the streams read the file again.
    // ponytail: only when syncAll runs (start, resume, network back); a cross-isolate notification if a worker ever writes while in foreground.
    _store.refreshAfterExternalWrites();
    await Future.wait([
      for (final account in await _store.accounts())
        // A Da ricollegare Account stops syncing until the user consents again.
        if (account.status == AccountStatus.attivo) _sync(account),
    ]);
  }

  @override
  Future<Result<void>> openConversation(
    String accountId,
    String conversationId,
  ) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = _provider(account);
    // Read here at once, offline too; the Provider hears it from the queue.
    await _store.markConversationRead(accountId, conversationId);
    // Fetched inside the Account's slot: no sync can apply a newer change between the fetch and the apply.
    // ponytail: the opening waits behind a running sync (an initial one too); a cursor check on apply if that ever hurts.
    final fetched = await _serial(accountId, () async {
      // Inviati and messages older than the sync window are not in the database yet.
      // ponytail: refetched on every opening (one request); remember complete Conversazioni if the quota ever matters.
      final fetched = await provider.fetchConversation(conversationId);
      if (fetched case Ok(:final value)) {
        await _store.applyPage(accountId, value, const {});
        await _store.markConversationRead(accountId, conversationId);
      }
      // Its own replay, after any batch a sync fetched before the read: it sends every intent queued so far.
      await _replay(accountId, provider);
      return fetched;
    });
    return switch (fetched) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> fetchBody(String accountId, String messageId) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    switch (await _provider(account).fetchBody(messageId)) {
      case Ok(:final value):
        await _store.saveBody(accountId, messageId, value);
        return const Ok(null);
      case Err(:final failure):
        debugPrint('[sync] $accountId: body $messageId failed, $failure');
        return Err(failure);
    }
  }

  @override
  Future<void> saveDraft(String accountId, OutgoingMessage draft) async {
    await _store.saveDraft(
      accountId,
      draft,
      updatedAt: _clock.now().millisecondsSinceEpoch,
    );
    // Swapped with no await in between: two saves in a row must not both keep a timer.
    final old = _draftTimers.remove(accountId);
    _draftTimers[accountId] = _clock
        .every(draftDebounce)
        .listen((_) => unawaited(flushDrafts(accountId)));
    await old?.cancel();
  }

  /// Sends the Account's pending Bozze at once. While the Provider's pause holds they stay
  /// pending and go with the first replay after it (the next poll or sync).
  @override
  Future<void> flushDrafts(String accountId) async {
    await _draftTimers.remove(accountId)?.cancel();
    if (_paused(accountId)) return;
    final account = await _account(accountId);
    // Da ricollegare: the queue waits for the reconnection, which syncs (and replays) again.
    if (account == null || account.status != AccountStatus.attivo) return;
    await _serial(accountId, () async {
      await _replay(accountId, _provider(account), flush: true);
    });
  }

  @override
  Future<Result<DateTime>> send(
    String accountId,
    OutgoingMessage message,
  ) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    // A second Invia of the same Message-ID (a reopened composer): the first one stands, unless it failed preparing.
    var existing = await _store.outgoing(accountId, message.messageId);
    if (existing != null && existing.failed) {
      await _store.dropOutgoing(accountId, message.messageId, existing.version);
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
    await _store.enqueueOutgoing(
      accountId,
      message,
      version: version,
      raw: '',
      sendAfter: OutboxDao.preparing,
    );
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
      (messageId, attachmentId) => GetIt.I<AttachmentRepository>().bytes(
        accountId,
        messageId,
        attachmentId,
      ),
    )) {
      case Ok(:final value):
        raw = value;
      case Err(:final failure):
        await _store.outgoingFailed(
          accountId,
          message.messageId,
          version: version,
        );
        await _releaseIfEmpty(accountId);
        return Err(failure);
    }
    // ponytail: the limit is Gmail's; per-Provider limits when other adapters arrive.
    if (raw.length > gmailSendLimitBytes) {
      await _store.outgoingFailed(
        accountId,
        message.messageId,
        version: version,
      );
      await _releaseIfEmpty(accountId);
      return const Err(SizeLimitFailure(gmailSendLimitBytes));
    }
    // The window starts once the MIME is ready: a slow download never eats the user's Annulla time.
    final sendAfter = _clock.now().add(sendWindow);
    if (!await _store.outgoingReady(
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
      unawaited(flushOutbox(accountId));
    });
    return Ok(sendAfter);
  }

  @override
  Future<String?> cancelSend(String accountId, String messageId) async {
    await _sendTimers.remove((accountId, messageId))?.cancel();
    final attempted =
        (await _store.outgoing(accountId, messageId))?.attempted ?? false;
    // Not behind the Account's queue: a replay waiting on a slow upload would send the row first.
    // The claim in the database refuses the cancel of a row that is going now (false).
    final cancelled = await _store.cancelOutgoing(
      accountId,
      messageId,
      _clock.now().millisecondsSinceEpoch,
    );
    await _releaseIfEmpty(accountId);
    if (!cancelled) return null;
    final account = attempted ? await _account(accountId) : null;
    if (account == null) return messageId;
    // ponytail: the original may or may not have been delivered; a new Message-ID keeps the two apart (an edit is never
    // taken for the original), and the next sync shows the original in Inviati if it went. The old remote draft is left to reconcile.
    final fresh = newMessageId(account.address);
    return await _store.rekeyDraft(accountId, messageId, fresh)
        ? fresh
        : messageId;
  }

  /// Lets the platform go once nothing of the Account is queued any more.
  Future<void> _releaseIfEmpty(String accountId) async {
    if (!_held.contains(accountId) || await _store.hasOutgoing(accountId)) {
      return;
    }
    _held.remove(accountId);
    try {
      await _background.release(accountId);
    } catch (e) {
      debugPrint('[sync] $accountId: background release failed, $e');
    }
  }

  /// Sends the Account's due outbox entries at once. While the Provider's pause holds they stay queued
  /// and go with the first replay after it (the next poll or sync); so do those of a Da ricollegare Account.
  @override
  Future<void> flushOutbox(String accountId) async {
    if (_paused(accountId)) return;
    final account = await _account(accountId);
    if (account == null || account.status != AccountStatus.attivo) return;
    await _serial(
      accountId,
      () => _replay(accountId, _provider(account), outboxOnly: true),
    );
  }

  @override
  Future<Result<OutgoingMessage>> openDraft(
    String accountId,
    String messageId,
  ) async {
    // ponytail: no guard on a queued Message-ID; the Bozze list hides it (watchAll) and Inviati reopens through cancelSend.
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final local = await _store.localDraft(accountId, messageId);
    final remote = await _store.remoteDraft(accountId, messageId);
    // The local copy, unless the Provider has a newer one and nothing here is waiting to go:
    // then it was edited elsewhere since, and the Provider's version is taken over.
    // ponytail: by the device clock against the Provider's date; a clock far ahead keeps the local copy.
    // A reply created here always stays ours: the Provider dates it at upload time, after `updatedAt`,
    // and an edit elsewhere cannot be merged (it would drop In-Reply-To, thread or forwarded attachments),
    // so never refuse it.
    if (local != null &&
        (local.pending ||
            local.draft.inReplyTo != null ||
            local.draft.attachments.isNotEmpty ||
            remote == null ||
            remote.message.date.millisecondsSinceEpoch <= local.updatedAt)) {
      return Ok(local.draft);
    }
    if (remote == null) return const Err(NotFoundFailure());
    // A reply written elsewhere: the save would drop its In-Reply-To, References and thread.
    // ponytail: the local Bozze of #37 carry them; a remote one is still refused because its headers
    // are not fetched (metadata sync has no In-Reply-To): read them from the message when people ask.
    if (await _store.hasSiblings(accountId, remote.message.id)) {
      return const Err(DraftReplyFailure());
    }
    var body = remote.body;
    if (body == null) {
      switch (await _provider(account).fetchBody(remote.message.id)) {
        case Ok(:final value):
          body = value;
          await _store.saveBody(accountId, remote.message.id, value);
        case Err(:final failure):
          // Offline: what we have.
          return local != null ? Ok(local.draft) : Err(failure);
      }
    }
    // The save replaces the whole message and the adapters only write text.
    // ponytail: refused; keep the attachments in the adapters if people ask.
    if (body.attachments?.isNotEmpty ?? false) {
      return const Err(DraftWithAttachmentsFailure());
    }
    final draft = OutgoingMessage(
      messageId: messageId,
      from: account.address,
      to: remote.message.to,
      cc: remote.message.cc,
      bcc: remote.message.bcc,
      subject: remote.message.subject,
      body: switch (body.kind) {
        BodyKind.html => body.content,
        BodyKind.testo => plainToHtml(body.content),
      },
    );
    await _store.adoptDraft(
      accountId,
      draft,
      updatedAt: remote.message.date.millisecondsSinceEpoch,
    );
    return Ok(draft);
  }

  /// Straight from the Provider, outside the Account's serial queue: a download never waits behind a sync.
  Future<Result<AttachmentBytes>> fetchAttachment(
    String accountId,
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    return _provider(account).fetchAttachment(
      messageId,
      attachmentId,
      onProgress: onProgress,
      cancel: cancel,
    );
  }

  Future<Account?> _account(String id) async =>
      (await _store.accounts()).where((a) => a.id == id).firstOrNull;

  /// Runs [op] after everything already queued for the Account; a failure does not block the queue.
  Future<T> _serial<T>(String accountId, Future<T> Function() op) {
    final run = (_tail[accountId] ?? Future<void>.value()).then((_) => op());
    _tail[accountId] = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Sends the offline queue (ADR 0008); what fails stays queued and the next poll retries it.
  /// A Bozza edited within [draftDebounce] waits for its timer, unless [flush] (leaving the composer, reconnection).
  /// An outbox entry goes once its window has ended: so a restart, a poll and the reconnection all send what is due.
  /// With [outboxOnly] only the outbox goes (the 10 s timer and the WorkManager isolate): Bozze uploads
  /// have no cross-isolate claim, so they stay with their own timers and the sync's replay.
  /// Called only from inside the Account's serial queue.
  Future<void> _replay(
    String accountId,
    MailProvider provider, {
    bool flush = false,
    bool outboxOnly = false,
  }) async {
    // A send ahead of this one in the queue may have just paused the Account.
    if (_paused(accountId)) return;
    final byValue = <bool, List<String>>{};
    for (final i in await _store.pendingIntents(accountId)) {
      if (outboxOnly) break;
      if (i.isRead case final read?) (byValue[read] ??= []).add(i.messageId);
    }
    for (final MapEntry(key: read, value: ids) in byValue.entries) {
      switch (await provider.setRead(ids, read: read)) {
        // Gone from the Provider: the intent is dropped in silence.
        case Ok() || Err(failure: NotFoundFailure()):
          await _store.readDone(accountId, ids, isRead: read);
        case Err(:final failure):
          debugPrint('[sync] $accountId: replay failed, $failure');
      }
    }
    for (final (:draft, :isNew, :updatedAt) in await _store.pendingDrafts(
      accountId,
    )) {
      if (outboxOnly) break;
      if (!flush &&
          _clock.now().millisecondsSinceEpoch - updatedAt <
              draftDebounce.inMilliseconds) {
        continue;
      }
      // Queued while an earlier upload was in flight: it goes with its own MIME.
      if (await _store.isQueued(accountId, draft.messageId)) continue;
      switch (await provider.saveDraft(draft, isNew: isNew)) {
        case Ok():
          // The message was queued or sent while the upload ran: the late remote Bozza must not survive.
          if (await _store.isQueued(accountId, draft.messageId) ||
              await _store.localDraft(accountId, draft.messageId) == null) {
            if (await provider.deleteDraft(draft.messageId)
                case Err(:final failure) when failure is! NotFoundFailure) {
              debugPrint(
                '[sync] $accountId: late draft delete failed, $failure',
              );
            }
            // A later Annulla reopens the row: it must upload as new, not as an update of the deleted copy.
            await _store.forgetRemoteDraft(accountId, draft.messageId);
            continue;
          }
          await _store.draftSynced(accountId, draft.messageId, updatedAt);
          debugPrint('[sync] $accountId: draft synced ${draft.messageId}');
        // Sent or deleted elsewhere: the local edit is dropped in silence (ADR 0008).
        case Err(failure: NotFoundFailure()):
          // Queued meanwhile: keep the row as new so Annulla reopens its content.
          if (await _store.isQueued(accountId, draft.messageId)) {
            await _store.forgetRemoteDraft(accountId, draft.messageId);
          } else {
            await _store.removeDraft(accountId, draft.messageId);
          }
        case Err(:final failure):
          debugPrint('[sync] $accountId: draft replay failed, $failure');
      }
    }
    final now = _clock.now().millisecondsSinceEpoch;
    outbox:
    for (final row in await _store.dueOutgoing(accountId, now)) {
      // Taken in the database first: the WorkManager isolate may be replaying the same row; the loser skips it.
      // ponytail: a crash mid-send keeps the row claimed, so its retry waits up to [sendClaim].
      // A fresh clock reading: earlier sends in this loop may have been slow.
      final claimAt = _clock.now().millisecondsSinceEpoch;
      if (!await _store.claimOutgoing(
        accountId,
        row.messageId,
        sendAfter: row.sendAfter,
        untilMs: claimAt + sendClaim.inMilliseconds,
        nowMs: claimAt,
      )) {
        continue;
      }
      switch (await provider.send(
        row.messageId,
        row.raw,
        threadId: row.conversationId,
      )) {
        case Ok(:final value):
          await _store.outgoingSent(
            accountId,
            row.messageId,
            providerId: value,
            date: now,
            sendAfter: row.sendAfter,
          );
          debugPrint('[sync] $accountId: sent ${row.messageId}');
        // Refused for good (too big, Bozza gone): kept as failed for the UI, never retried (ADR 0008).
        case Err(
          failure: final f &&
              (SizeLimitFailure() || NotFoundFailure() || RejectedFailure()),
        ):
          await _store.outgoingFailed(accountId, row.messageId);
          debugPrint('[sync] $accountId: send refused ${row.messageId}, $f');
        // Rate limited: the Account waits for the deadline, as after a sync; the rest stays queued.
        case Err(failure: RateLimitFailure(:final retryAfter?)):
          _pausedUntil[accountId] = retryAfter;
          await _store.unclaimOutgoing(accountId, row.messageId);
          debugPrint('[sync] $accountId: send paused until $retryAfter');
          break outbox;
        case Err(:final failure):
          await _store.unclaimOutgoing(accountId, row.messageId);
          debugPrint('[sync] $accountId: send failed, $failure');
      }
    }
    await _releaseIfEmpty(accountId);
  }

  Future<void> _poll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        if (account.status == AccountStatus.attivo) _sync(account),
    ]);
  }

  /// One change-signal subscription per attivo Account.
  void _watchSignals(List<Account> accounts) {
    final attivi = {
      for (final a in accounts)
        if (a.status == AccountStatus.attivo) a.id: a,
    };
    for (final id in _signals.keys.toList()) {
      if (!attivi.containsKey(id)) {
        unawaited(_signals.remove(id)!.cancel());
      }
    }
    for (final a in attivi.values) {
      if (_signals.containsKey(a.id)) continue;
      _signals[a.id] = _provider(a).changes.listen((signal) {
        switch (signal) {
          // Up: whatever changed while it was down.
          case ChangeSignal.up || ChangeSignal.changed:
            unawaited(_sync(a));
          case ChangeSignal.down:
        }
      });
    }
  }

  /// The Account's adapter, created on first use; tests register fakes by Account id beforehand.
  MailProvider _provider(Account account) {
    final g = GetIt.I;
    if (!g.isRegistered<MailProvider>(instanceName: account.id)) {
      // ponytail: Gmail is the only Provider of step 1; Microsoft and IMAP adapters branch on account.provider at steps 4-5.
      g.registerLazySingleton<MailProvider>(
        () => GmailProvider(account.id, g(), g(), g()),
        instanceName: account.id,
      );
    }
    return g<MailProvider>(instanceName: account.id);
  }

  /// Queues a sync of the Account; requests made before it starts share it, a request while it runs queues another.
  Future<void> _sync(Account account) {
    final id = account.id;
    if (_paused(id)) return Future.value();
    return _queuedSync[id] ??= _serial(id, () {
      _queuedSync.remove(id);
      return _syncOnce(id, _provider(account));
    });
  }

  /// True while the Provider's pause holds; a lapsed pause is forgotten.
  bool _paused(String id) {
    if (_pausedUntil[id] case final until?) {
      if (_clock.now().isBefore(until)) return true;
      _pausedUntil.remove(id);
    }
    return false;
  }

  Future<void> _syncOnce(String accountId, MailProvider provider) async {
    // The queue first, so the sync brings back what the user did offline.
    await _replay(accountId, provider);
    if (_paused(accountId)) return;
    final cursor = await _store.cursor(accountId);
    var full = cursor == null;
    Future<Result<SyncBatch>> initial() {
      debugPrint('[sync] $accountId: initial sync start');
      return provider.initialSync(
        onPage: (messages, bodies) =>
            _store.applyPage(accountId, messages, bodies),
      );
    }

    if (!full) debugPrint('[sync] $accountId: incremental sync start');
    var result = full
        ? await initial()
        : await provider.incrementalSync(cursor);
    if (result case Err(failure: NotFoundFailure())) {
      // Expired cursor: start over.
      full = true;
      result = await initial();
    }
    switch (result) {
      case Ok(:final value):
        // The cursor is saved here, from the complete batch: pages alone never save it.
        await _store.applySync(accountId, value, fullSnapshot: full);
        debugPrint(
          '[sync] $accountId: ${full ? 'initial' : 'incremental'} sync end, '
          '${value.messages.length} messages, ${value.removedMessageIds.length} removed',
        );
      case Err(:final failure):
        debugPrint('[sync] $accountId: failed, $failure');
        if (failure case RateLimitFailure(:final retryAfter?)) {
          _pausedUntil[accountId] = retryAfter;
          debugPrint('[sync] $accountId: paused until $retryAfter');
        }
        // ponytail: a fixed retry on the next poll; exponential backoff if Providers keep refusing.
        if (failure is AuthFailure) {
          await _store.setStatus(accountId, AccountStatus.daRicollegare);
        }
    }
  }
}

@module
abstract class SyncModule {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
