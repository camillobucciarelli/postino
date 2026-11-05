import 'message.dart';
import 'result.dart';

/// What the UI may ask of the sync engine: it still reads only from the database (ADR 0003).
abstract interface class MailSync() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Syncs every attivo Account now (pull-to-refresh); completes when done.
  Future<void> syncAll();

  /// Marks the Conversazione read (locally at once, on the Provider now or when back online)
  /// and downloads its messages missing from the database (Inviati, older than 90 days);
  /// [Err] when they could not be downloaded (offline...).
  Future<Result<void>> openConversation(String accountId, String conversationId);

  /// Downloads a message body into the database; [Err] when it could not (offline...).
  Future<Result<void>> fetchBody(String accountId, String messageId);

  /// Keeps the Bozza here at once (every edit) and on the Provider after a pause in the edits,
  /// or when back online / reconnected; the same Message-ID updates the same Bozza.
  Future<void> saveDraft(String accountId, OutgoingMessage draft);

  /// Sends the Account's pending Bozze to the Provider now (on leaving the composition);
  /// completes offline or Da ricollegare too, the Bozze stay queued.
  Future<void> flushDrafts(String accountId);

  /// Queues the message (#36): it goes after `sendWindow` (Annulla invio), also offline (when the network returns)
  /// or after a restart; [SizeLimitFailure] when it is too big for the Provider, [OfflineFailure] when a forwarded
  /// attachment is neither cached nor downloadable, and nothing is queued. Ok carries the end of the Annulla window.
  Future<Result<DateTime>> send(String accountId, OutgoingMessage message);

  /// Takes the message out of the outbox within the window, or once the Provider refused it for good;
  /// null when it already went (or was never queued). The Bozza stays, so the UI can reopen it: the result is its
  /// Message-ID, [messageId] itself, or a new one when a send was already attempted (its delivery is uncertain).
  Future<String?> cancelSend(String accountId, String messageId);

  /// Sends the Account's due outbox entries now; completes offline or Da ricollegare too, they stay queued.
  Future<void> flushOutbox(String accountId);

  /// The Bozza to resume: the local one, or one of another client (its body downloaded if missing,
  /// then kept here); [NotFoundFailure] when there is none.
  Future<Result<OutgoingMessage>> openDraft(String accountId, String messageId);

  /// One attachment straight from the Provider, outside the Account's queue (a download never waits behind
  /// a sync); for the attachment cache, the UI goes through `AttachmentRepository`.
  Future<Result<AttachmentBytes>> fetchAttachment(
    String accountId,
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  });

  /// Creates the Etichetta on the Provider and lists it here; not queued: [Err] offline or Da ricollegare.
  /// Idempotent on the name: an existing Etichetta is returned.
  Future<Result<Label>> createLabel(String accountId, String name);

  /// Puts the Etichetta [labelId] on the message (with [add] false, takes it off): here at once, on the Provider
  /// now or when back online (ADR 0008). Completes offline too, the intent stays queued.
  Future<void> setLabel(String accountId, String messageId, String labelId, {required bool add});

  /// [setLabel] on every message of a Conversazione: all queued, then a single replay.
  Future<void> setConversationLabel(String accountId, Iterable<String> messageIds, String labelId, {required bool add});

  /// Brings the whole Conversazione here (the sync window leaves older messages out) without reading it:
  /// before putting an Etichetta on all of it. [Err] offline or on a failed fetch.
  Future<Result<void>> completeConversation(String accountId, String conversationId);
}
