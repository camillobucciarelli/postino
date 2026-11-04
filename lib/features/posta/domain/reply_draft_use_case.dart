import 'package:injectable/injectable.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/html_text.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/reply.dart';
import '../../../core/domain/result.dart';
import 'quote_date_label.dart';

/// Rispondi, Rispondi a tutti, Inoltra (#37). The names are part of the widget keys (`message-reply-…`).
enum ReplyKind { reply, replyAll, forward }

/// What a Bozza of [kind] starts from: [message] with its body as known once downloaded.
class ReplySource {
  const ReplySource(this.kind, this.message, this.body);
  final ReplyKind kind;
  final Message message;
  final MessageBody? body;

  /// Inoltra needs the attachments too: unknown when the body could not be downloaded
  /// (or was stored before database v9 and could not be downloaded again).
  bool get unavailable =>
      kind == ReplyKind.forward && body?.attachments == null;
}

/// Saves the Bozza with the Citazione of a message, in two steps: [source] downloads the body if missing,
/// [save] makes the Bozza through the offline queue (ADR 0008). The caller decides in between whether it
/// still wants it (a view gone meanwhile saves nothing) and says when Inoltra is [ReplySource.unavailable].
@injectable
class ReplyDraftUseCase {
  ReplyDraftUseCase(this._sync, this._inbox);
  final MailSync _sync;
  final InboxRepository _inbox;

  /// [messageId] in [messages] (the last one by default), its body downloaded first when it is not here
  /// (for Inoltra, also when its attachments are not known).
  Future<ReplySource> source(
    String accountId,
    String conversationId,
    List<ConversationMessage> messages,
    ReplyKind kind, {
    String? messageId,
  }) async {
    var (:message, :body) = messageId == null
        ? messages.last
        : messages.firstWhere((m) => m.message.id == messageId);
    if ((body == null ||
            kind == ReplyKind.forward && body.attachments == null) &&
        await _sync.fetchBody(accountId, message.id) is Ok) {
      // The database stream answers with the rows as they are now.
      final fresh = await _inbox
          .watchConversation(accountId, conversationId)
          .first;
      body = fresh.where((m) => m.message.id == message.id).firstOrNull?.body;
    }
    return ReplySource(kind, message, body);
  }

  /// Saves the Bozza from [account] answering (or forwarding) [s]; returns its Message-ID.
  /// Without a body, Rispondi quotes the snippet.
  Future<String> save(Account account, ReplySource s) async {
    final message = s.message;
    final html = switch (s.body) {
      MessageBody(kind: BodyKind.html, :final content) => content,
      MessageBody(:final content) => plainToHtml(content),
      null => plainToHtml(message.snippet),
    };
    // La frase della citazione è sempre in italiano: la data deve concordare.
    await initializeDateFormatting('it');
    final dateLabel = quoteDateLabel(message.date);
    final id = newMessageId(account.address);
    final draft = switch (s.kind) {
      ReplyKind.forward => buildForward(
        original: message,
        originalHtml: html,
        self: account.address,
        messageId: id,
        dateLabel: dateLabel,
        attachments: s.body?.attachments ?? const [],
      ),
      _ => buildReply(
        original: message,
        originalHtml: html,
        self: account.address,
        messageId: id,
        all: s.kind == ReplyKind.replyAll,
        dateLabel: dateLabel,
      ),
    };
    await _sync.saveDraft(account.id, draft);
    return id;
  }
}
