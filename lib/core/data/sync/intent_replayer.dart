import 'package:flutter/foundation.dart';

import '../../domain/action_outcome.dart';
import '../../domain/draft_content.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/error_log.dart';
import '../../domain/mail_provider.dart';
import '../../domain/outbox_repository.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../mail_store.dart';

/// Pause in the edits after which a Bozza goes to the Provider (#35).
const draftDebounce = Duration(seconds: 5);

/// Replays the offline queue of an Account (ADR 0008): the Azioni, then the Bozze not on the Provider yet.
/// What fails stays queued and the next poll retries it. Called only from inside the Account's serial queue
/// of the sync engine: it never runs beside a sync or a send of the same Account.
class IntentReplayer(
  final MailStore _store,
  final OutboxRepository _outbox,
  final Clock _clock,
  final ErrorLog _log, {

  /// The Provider rate-limited the Account: no sync nor send before the deadline.
  required final void Function(String accountId, DateTime until) _pause,
}) {
  /// `pause` tells the engine the Provider rate-limited the Account.
  this;

  /// A Bozza edited within [draftDebounce] waits for its timer, unless [flush] (leaving the composer, reconnection).
  Future<void> replay(String accountId, MailProvider provider, {bool flush = false}) async {
    // Rate limited: the Bozze wait for the deadline too.
    if (await _replayActions(accountId, provider)) return;
    await _replayDrafts(accountId, provider, flush: flush);
  }

  /// One conditional call per voce (ADR 0008): applied or message gone, it leaves the queue; a Conflitto is kept
  /// open and never retried. A passing failure (offline, quota, auth) stops at once: each call would wait out the
  /// transport's backoff, holding the Account's queue for minutes; the rest stays queued for the next replay.
  /// True when it paused the Account.
  Future<bool> _replayActions(String accountId, MailProvider provider) async {
    for (final captured in await _store.pendingActions(accountId, _clock.now())) {
      // Read again just before sending: what the user did during the earlier calls (resolved the Conflitto, merged
      // another Azione) wins over the list taken at the start.
      // ponytail: a change during this very call still races it; a per-voce lock if that ever shows.
      final q = await _store.currentAction(accountId, captured);
      if (q == null) continue;
      switch (await provider.applyAction(q.messageId, q.action, expected: q.expected)) {
        // Gone from the Provider: the voce is dropped in silence.
        case Ok(value: ActionApplied() || ActionMessageGone()) || Err(failure: NotFoundFailure()):
          await _store.actionDone(accountId, q);
        case Ok(value: ActionConflict(:final providerValue, :final movedTo)):
          debugPrint('[sync] $accountId: Conflitto on ${q.messageId} ${q.action.attribute}');
          await _store.actionConflict(accountId, q, providerValue, movedTo: movedTo);
        // ponytail: a refusal (an Etichetta deleted elsewhere) would be retried forever, and the message may never
        // come back in the history: the voce is dropped and the change undone here.
        case Err(failure: final f && RejectedFailure()):
          _log.failure('action replay $accountId', f);
          await _store.actionRejected(accountId, q);
        case Err(:final failure):
          debugPrint('[sync] $accountId: action replay failed, $failure');
          _log.failure('action replay $accountId', failure);
          // Rate limited: the Account waits for the deadline, as after a sync or a send.
          if (failure case RateLimitFailure(:final retryAfter?)) {
            _pause(accountId, retryAfter);
            return true;
          }
          return false;
      }
    }
    return false;
  }

  Future<void> _replayDrafts(String accountId, MailProvider provider, {required bool flush}) async {
    for (final (:draft, :isNew, :updatedAt, :expected) in await _outbox.pendingDrafts(accountId)) {
      if (!flush && _clock.now().millisecondsSinceEpoch - updatedAt < draftDebounce.inMilliseconds) {
        continue;
      }
      // Queued while an earlier upload was in flight: it goes with its own MIME.
      if (await _outbox.isQueued(accountId, draft.messageId)) continue;
      switch (await provider.saveDraft(draft, isNew: isNew, expected: expected)) {
        // Edited elsewhere too (#149): the Bozza waits for the user's choice, its content here kept.
        case Ok(value: DraftDiverged(:final provider)):
          // Queued meanwhile: the send carries the version here, nothing to choose.
          if (await _outbox.isQueued(accountId, draft.messageId)) continue;
          debugPrint('[sync] $accountId: Conflitto on draft ${draft.messageId}');
          await _outbox.draftConflict(accountId, draft.messageId, provider);
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
          await _outbox.draftSynced(
            accountId,
            draft.messageId,
            updatedAt,
            fingerprint: DraftContent.of(draft).fingerprint,
          );
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
          _log.failure('draft replay $accountId', failure);
      }
    }
  }
}
