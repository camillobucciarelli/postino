import '../../domain/action_outcome.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';

/// The adapter of an iCloud or IMAP Account until the IMAP adapter exists (T3): every sync is empty, so the Account
/// stays attivo without mail instead of failing; everything else is refused.
// ponytail: placeholder of v1 step 4; the IMAP adapter replaces it in provider_factory.dart.
class const UnsyncedProvider() implements MailProvider {
  static const _unsupported = Err<Never>(UnexpectedFailure('IMAP adapter not available yet'));

  @override
  Future<Result<void>> refreshAuth() async => const Ok(null);

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) async => const Ok(SyncBatch(cursor: ''));

  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) async => Ok(SyncBatch(cursor: cursor));

  @override
  Stream<ChangeSignal> get changes => const Stream.empty();

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) async => _unsupported;

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) async => _unsupported;

  @override
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected}) async =>
      _unsupported;

  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async => _unsupported;

  @override
  Future<Result<String>> send(String messageId, String raw, {String? threadId}) async => _unsupported;

  @override
  Future<Result<DraftOutcome>> saveDraft(OutgoingMessage draft, {required bool isNew, String? expected}) async =>
      _unsupported;

  @override
  Future<Result<void>> deleteDraft(String messageId) async => _unsupported;

  @override
  Future<Result<Label>> createLabel(String name) async => _unsupported;
}
