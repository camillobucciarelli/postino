import '../../domain/mail_provider.dart';
import 'account_gate.dart';
import 'account_queue.dart';
import 'intent_replayer.dart';
import 'outbox_sender.dart';
import 'provider_factory.dart';

/// Sends an Account's offline queue (ADR 0008): the Azioni and Bozze through [IntentReplayer], the due outbox
/// entries through [OutboxSender]. Nothing goes while the Provider's pause holds nor once the removal started (#174).
class QueueReplay(
  final IntentReplayer _intents,
  final OutboxSender _outbox,
  final AccountGate _gate,
  final AccountQueue _queue,
) {
  /// The intents and Bozze, then the due outbox entries.
  /// With [outboxOnly] only the outbox goes (the 10 s timer and the WorkManager isolate): Bozze uploads
  /// have no cross-isolate claim, so they stay with their own timers and the sync's replay.
  /// Called only from inside the Account's serial queue.
  Future<void> run(String accountId, MailProvider provider, {bool flush = false, bool outboxOnly = false}) async {
    // Its removal started (#174): nothing more goes to the Provider.
    if (_gate.removed(accountId)) return;
    // A send ahead of this one in the queue may have just paused the Account.
    if (_gate.paused(accountId)) return;
    if (!outboxOnly) await _intents.replay(accountId, provider, flush: flush);
    // The replay may have just paused it (a rate-limited Etichetta): no send before the deadline.
    if (_gate.paused(accountId)) return;
    await _outbox.sendDue(accountId, provider);
  }

  /// Sends the Account's queue, in its turn, unless it may not go to the Provider now.
  Future<void> ifActive(String accountId) async {
    if (await _gate.active(accountId) case final account?) {
      await _queue.run(accountId, () => run(accountId, providerFor(account)));
    }
  }

  /// Before a sync, the Azioni: a value changed elsewhere since they were queued is a Conflitto, not overwritten.
  Future<void> beforeSync(String accountId, MailProvider provider) async {
    if (!_gate.paused(accountId)) await _intents.replayActions(accountId, provider);
  }

  /// After a sync, the Bozze and the outbox.
  Future<void> afterSync(String accountId, MailProvider provider) async {
    await _intents.replayDrafts(accountId, provider);
    if (!_gate.paused(accountId)) await _outbox.sendDue(accountId, provider);
  }
}
