import 'inbox_repository.dart';
import 'message.dart';

/// An outbox row as the sender reads it (#36): [version] tags its preparation, [sendAfter] (ms since epoch, UTC)
/// is when Annulla invio ends, [attempted] once a send was tried, [failed] when the Provider refused it for good.
typedef OutboxItem = ({
  String messageId,
  int version,
  String raw,
  String? conversationId,
  int sendAfter,
  bool attempted,
  bool failed,
});

/// The local copy of a Bozza: [pending] while it has edits not on the Provider yet.
typedef LocalDraft = ({OutgoingMessage draft, bool pending, int updatedAt});

/// A Bozza whose content is not on the Provider yet; [isNew] when it never was.
typedef PendingDraft = ({OutgoingMessage draft, bool isNew, int updatedAt});

/// The offline queue of what leaves the device (ADR 0008): the Bozze (#35) and the outbox (#36).
/// Only the sync engine writes here; the UI reads through [InboxRepository].
abstract interface class OutboxRepository {
  // --- Bozze (#35) ---
  Future<void> saveDraft(String accountId, OutgoingMessage draft, {required int updatedAt});

  /// A Bozza as the Provider has it (another client's, or edited elsewhere), kept here as already synced.
  Future<void> adoptDraft(String accountId, OutgoingMessage draft, {required int updatedAt});

  Future<LocalDraft?> localDraft(String accountId, String messageId);

  /// The Provider's DRAFT message with this Message-ID, as stored, with its body if downloaded.
  Future<ConversationMessage?> remoteDraft(String accountId, String messageId);

  /// Whether another message shares the Conversazione of this one.
  Future<bool> hasSiblings(String accountId, String messageId);

  Future<List<PendingDraft>> pendingDrafts(String accountId);

  /// True while [messageId] waits in the outbox: a Bozza PUT then would only delay its send in the Account's queue.
  Future<bool> isQueued(String accountId, String messageId);

  /// The content of [updatedAt] reached the Provider.
  Future<void> draftSynced(String accountId, String messageId, int updatedAt);

  /// The remote copy was deleted: the local Bozza is new again.
  Future<void> forgetRemoteDraft(String accountId, String messageId);

  Future<void> removeDraft(String accountId, String messageId);

  /// Re-keys the local Bozza [from] as [to], as new; false when there is none.
  Future<bool> rekeyDraft(String accountId, String from, String to);

  // --- Outbox (#36) ---
  /// Queues [message] with its rendered MIME [raw]; it goes once [sendAfter] (ms since epoch, UTC) has passed.
  Future<void> enqueueOutgoing(
    String accountId,
    OutgoingMessage message, {
    required int version,
    required String raw,
    required int sendAfter,
  });

  /// The row of [messageId], if queued (or still being prepared).
  Future<OutboxItem?> outgoing(String accountId, String messageId);

  /// The row has its MIME and deadline; false when it was cancelled (or replaced) while preparing.
  Future<bool> outgoingReady(
    String accountId,
    String messageId, {
    required int version,
    required String raw,
    required int sendAfter,
  });

  /// Drops the row of a preparation that failed.
  Future<void> dropOutgoing(String accountId, String messageId, int version);

  /// Annulla invio: true when the row was still there and no sender (another isolate) is sending it now.
  Future<bool> cancelOutgoing(String accountId, String messageId, int nowMs);

  /// The outbox rows whose window ended by [nowMs].
  Future<List<OutboxItem>> dueOutgoing(String accountId, int nowMs);

  /// True while the Account has anything queued to send (a failed row waits for the user, not the platform).
  Future<bool> hasOutgoing(String accountId);

  /// Takes the row version read at [sendAfter] for this sender until [untilMs] (#36); false when another isolate
  /// holds it or it was cancelled and queued again meanwhile.
  Future<bool> claimOutgoing(
    String accountId,
    String messageId, {
    required int sendAfter,
    required int untilMs,
    required int nowMs,
  });

  /// A send failed and may be retried: the row is free again, for the next replay of either isolate.
  Future<void> unclaimOutgoing(String accountId, String messageId);

  /// The Provider refused the message for good: it stays, shown as failed, and is not retried.
  /// With [version], only that preparation's row.
  Future<void> outgoingFailed(String accountId, String messageId, {int? version});

  /// The Provider has the message as [providerId]: the outbox row and the local Bozza go, and the message is
  /// stored at once under Inviati, so the folder shows it before the next sync upserts the same id.
  Future<void> outgoingSent(
    String accountId,
    String messageId, {
    required String providerId,
    required int date,
    required int sendAfter,
  });
}
