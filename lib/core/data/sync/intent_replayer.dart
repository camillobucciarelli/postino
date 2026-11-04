import 'package:flutter/foundation.dart';

import '../../domain/mail_provider.dart';
import '../../domain/outbox_repository.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../mail_store.dart';

/// Pause in the edits after which a Bozza goes to the Provider (#35).
const draftDebounce = Duration(seconds: 5);

/// Replays the offline queue of an Account (ADR 0008): the read and Etichette intents, then the Bozze
/// not on the Provider yet.
/// What fails stays queued and the next poll retries it. Called only from inside the Account's serial queue
/// of the sync engine: it never runs beside a sync or a send of the same Account.
class IntentReplayer(
  final MailStore _store,
  final OutboxRepository _outbox,
  final Clock _clock, {

  /// The Provider rate-limited the Account: no sync nor send before the deadline.
  required final void Function(String accountId, DateTime until) _pause,
}) {
  /// `pause` tells the engine the Provider rate-limited the Account.
  this;

  /// A Bozza edited within [draftDebounce] waits for its timer, unless [flush] (leaving the composer, reconnection).
  Future<void> replay(String accountId, MailProvider provider, {bool flush = false}) async {
    await _replayReads(accountId, provider);
    await _replayLabels(accountId, provider);
    await _replayDrafts(accountId, provider, flush: flush);
  }

  Future<void> _replayReads(String accountId, MailProvider provider) async {
    final byValue = <bool, List<String>>{};
    for (final i in await _store.pendingIntents(accountId)) {
      if (i.isRead case final read?) (byValue[read] ??= []).add(i.messageId);
    }
    for (final MapEntry(key: read, value: ids) in byValue.entries) {
      switch (await provider.setRead(ids, read: read)) {
        // Gone from the Provider: the intent is dropped in silence.
        case Ok() || Err(failure: NotFoundFailure()):
          await _store.readDone(accountId, ids, isRead: read);
        case Err(:final failure):
          debugPrint('[sync] $accountId: replay failed, $failure');
          return;
      }
    }
  }

  /// One call per message and Etichetta: a message gone fails alone, and its intent is dropped.
  /// A passing failure (offline, quota, auth) stops at once: each call would wait out the transport's backoff,
  /// holding the Account's queue for minutes; the rest stays queued for the next replay.
  Future<void> _replayLabels(String accountId, MailProvider provider) async {
    for (final i in await _store.pendingLabelIntents(accountId)) {
      switch (await provider.setLabel(i.messageId, i.labelId, add: i.added)) {
        case Ok() || Err(failure: NotFoundFailure()):
          await _store.labelDone(accountId, i.messageId, i.labelId, added: i.added);
        // ponytail: a refusal (an Etichetta deleted elsewhere) would be retried forever, and the message may never
        // come back in the history: the intent is dropped and the change undone here.
        case Err(failure: RejectedFailure()):
          await _store.labelRejected(accountId, i.messageId, i.labelId, added: i.added);
        case Err(:final failure):
          debugPrint('[sync] $accountId: label replay failed, $failure');
          // Rate limited: the Account waits for the deadline, as after a sync or a send.
          if (failure case RateLimitFailure(:final retryAfter?)) _pause(accountId, retryAfter);
          return;
      }
    }
  }

  Future<void> _replayDrafts(String accountId, MailProvider provider, {required bool flush}) async {
    for (final (:draft, :isNew, :updatedAt) in await _outbox.pendingDrafts(accountId)) {
      if (!flush && _clock.now().millisecondsSinceEpoch - updatedAt < draftDebounce.inMilliseconds) {
        continue;
      }
      // Queued while an earlier upload was in flight: it goes with its own MIME.
      if (await _outbox.isQueued(accountId, draft.messageId)) continue;
      switch (await provider.saveDraft(draft, isNew: isNew)) {
        case Ok():
          // The message was queued or sent while the upload ran: the late remote Bozza must not survive.
          if (await _outbox.isQueued(accountId, draft.messageId) ||
              await _outbox.localDraft(accountId, draft.messageId) == null) {
            if (await provider.deleteDraft(draft.messageId) case Err(:final failure) when failure is! NotFoundFailure) {
              debugPrint('[sync] $accountId: late draft delete failed, $failure');
            }
            // A later Annulla reopens the row: it must upload as new, not as an update of the deleted copy.
            await _outbox.forgetRemoteDraft(accountId, draft.messageId);
            continue;
          }
          await _outbox.draftSynced(accountId, draft.messageId, updatedAt);
          debugPrint('[sync] $accountId: draft synced ${draft.messageId}');
        // Sent or deleted elsewhere: the local edit is dropped in silence (ADR 0008).
        case Err(failure: NotFoundFailure()):
          // Queued meanwhile: keep the row as new so Annulla reopens its content.
          if (await _outbox.isQueued(accountId, draft.messageId)) {
            await _outbox.forgetRemoteDraft(accountId, draft.messageId);
          } else {
            await _outbox.removeDraft(accountId, draft.messageId);
          }
        case Err(:final failure):
          debugPrint('[sync] $accountId: draft replay failed, $failure');
      }
    }
  }
}
