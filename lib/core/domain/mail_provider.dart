import 'message.dart';
import 'result.dart';

/// What a sync returns: changes since the previous cursor (everything, for the initial sync).
class SyncBatch {
  const SyncBatch({
    required this.cursor,
    this.messages = const [],
    this.labels = const [],
    this.removedMessageIds = const [],
    this.bodies = const {},
  });

  /// Opaque to the core: Gmail historyId, Graph delta token, IMAP modseq...
  final String cursor;
  final List<Message> messages;
  final List<Label> labels;
  final List<String> removedMessageIds;

  /// Bodies downloaded with the sync, by Provider-side message id: the inbox ones (ADR 0003).
  final Map<String, String> bodies;
}

/// What the change signal reports: it came [up], something [changed], or it went [down].
/// While it is down the sync engine falls back to polling (ADR 0008).
enum ChangeSignal { up, changed, down }

/// The single adapter interface (ADR 0002), one instance per Account.
// ponytail: Search and conditional Action join the interface at steps 3 and 6.
abstract interface class MailProvider {
  /// Refreshes credentials; a definitive refusal is [AuthFailure].
  Future<Result<void>> refreshAuth();

  /// Headers of the last 90 days with Labels and Conversations, plus the inbox bodies.
  Future<Result<SyncBatch>> initialSync();

  /// Changes since [cursor]; an expired cursor is [NotFoundFailure], and the caller redoes the initial sync.
  Future<Result<SyncBatch>> incrementalSync(String cursor);

  /// "Something changed" signal (IMAP IDLE on the inbox); data comes from [incrementalSync].
  Stream<ChangeSignal> get changes;

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
