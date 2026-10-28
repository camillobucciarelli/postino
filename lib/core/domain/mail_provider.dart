import 'message.dart';
import 'result.dart';

/// What a sync returns: changes since the previous cursor (everything, for the initial sync).
class SyncBatch {
  const SyncBatch({
    required this.cursor,
    this.messages = const [],
    this.labels = const [],
    this.removedMessageIds = const [],
  });

  /// Opaque to the core: Gmail historyId, Graph delta token, IMAP modseq...
  final String cursor;
  final List<Message> messages;
  final List<Label> labels;
  final List<String> removedMessageIds;
}

/// The single adapter interface (ADR 0002), one instance per Account.
// ponytail: Search and conditional Action join the interface at steps 3 and 6.
abstract interface class MailProvider {
  /// Refreshes credentials; a definitive refusal is [AuthFailure].
  Future<Result<void>> refreshAuth();

  /// Headers of the last 90 days with Labels and Conversations, plus the inbox bodies.
  Future<Result<SyncBatch>> initialSync();

  Future<Result<SyncBatch>> incrementalSync(String cursor);

  /// "Something changed" signal (IMAP IDLE); data comes from [incrementalSync].
  Stream<void> get changes;

  Future<Result<String>> fetchBody(String messageId);

  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId,
  );

  /// Idempotent on [OutgoingMessage.messageId].
  Future<Result<void>> send(OutgoingMessage message);

  Future<Result<void>> saveDraft(OutgoingMessage draft);

  Future<Result<void>> deleteDraft(String messageId);
}
