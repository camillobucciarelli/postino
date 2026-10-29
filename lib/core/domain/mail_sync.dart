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
}
