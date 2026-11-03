import 'message.dart';
import 'result.dart';

/// What the UI may ask of the sync engine: it still reads only from the database (ADR 0003).
abstract interface class MailSync {
  /// Syncs every attivo Account now (pull-to-refresh); completes when done.
  Future<void> syncAll();

  /// Marks the Conversazione read (locally at once, on the Provider now or when back online)
  /// and downloads its messages missing from the database (Inviati, older than 90 days);
  /// [Err] when they could not be downloaded (offline...).
  Future<Result<void>> openConversation(
    String accountId,
    String conversationId,
  );

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
  /// false when it already went (or was never queued). The Bozza stays, so the UI can reopen it.
  Future<bool> cancelSend(String accountId, String messageId);

  /// Sends the Account's due outbox entries now; completes offline or Da ricollegare too, they stay queued.
  Future<void> flushOutbox(String accountId);

  /// The Bozza to resume: the local one, or one of another client (its body downloaded if missing,
  /// then kept here); [NotFoundFailure] when there is none.
  Future<Result<OutgoingMessage>> openDraft(String accountId, String messageId);
}
