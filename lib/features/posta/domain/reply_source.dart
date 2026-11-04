import '../../../core/domain/message.dart';
import 'reply_kind.dart';

/// What a Bozza of [kind] starts from: [message] with its body as known once downloaded.
class ReplySource {
  const ReplySource(this.kind, this.message, this.body);
  final ReplyKind kind;
  final Message message;
  final MessageBody? body;

  /// Inoltra needs the attachments too: unknown when the body could not be downloaded
  /// (or was stored before database v9 and could not be downloaded again).
  bool get unavailable => kind == ReplyKind.forward && body?.attachments == null;
}
