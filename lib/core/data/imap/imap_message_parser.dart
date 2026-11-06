import 'package:enough_mail/enough_mail.dart' show ContentDisposition, DateCodec, MediaSubtype, MimeMessage, MimePart;

import '../../domain/html_text.dart';
import '../../domain/mailbox.dart';
import '../../domain/message.dart';

/// The Provider-side id of a message: `cartella/UIDVALIDITY/UID` (the folder's decoded path may hold `/` itself).
String imapMessageId(String path, int uidValidity, int uid) => '$path/$uidValidity/$uid';

/// The parts of an [imapMessageId]; null for an id this adapter did not make.
({String path, int uidValidity, int uid})? parseImapMessageId(String id) {
  final m = RegExp(r'^(.+)/(\d+)/(\d+)$').firstMatch(id);
  if (m == null) return null;
  return (path: m[1]!, uidValidity: int.parse(m[2]!), uid: int.parse(m[3]!));
}

/// What a FETCH gives of one message: the [Message] (its Conversazione still empty, `imap_threads.dart` fills it),
/// the `In-Reply-To` it answers and, when the whole message was fetched, its body.
typedef ImapParsed = ({Message message, String? inReplyTo, MessageBody? body});

/// [mime] from a `UID FETCH` of FLAGS, INTERNALDATE and the header (or the whole message, `BODY.PEEK[]`), found in
/// the folder whose Etichetta is [labelId] under the id [id]; [withBody] when it was the whole message.
/// The Stella is `\Flagged`, letto is `\Seen`.
ImapParsed parseImapMessage(MimeMessage mime, {required String id, required String labelId, bool withBody = false}) {
  String header(String name) => mime.getHeaderValue(name) ?? '';
  List<String> addresses(String name) => [for (final m in parseMailboxes(header(name))) formatMailbox(m)];
  final from = parseMailbox(header('from'));
  final body = withBody ? _body(mime) : null;
  final message = Message(
    id: id,
    messageId: header('message-id').trim(),
    conversationId: '',
    labelIds: [labelId, if (mime.isFlagged) starredLabelId],
    isRead: mime.isSeen,
    isStarred: mime.isFlagged,
    from: from.address,
    fromName: from.name,
    to: addresses('to'),
    cc: addresses('cc'),
    bcc: addresses('bcc'),
    subject: decodeWords(header('subject')),
    snippet: switch (body) {
      MessageBody(kind: BodyKind.html, :final content) => listSnippet(content),
      MessageBody(:final content) => listSnippet(plainToHtml(content)),
      null => '',
    },
    date: (mime.decodeDate() ?? _internalDate(mime) ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc(),
    replyTo: switch (parseMailboxes(header('reply-to'))) {
      [final m, ...] => formatMailbox(m),
      _ => null,
    },
    references: _ids(header('references')),
  );
  return (message: message, inReplyTo: _ids(header('in-reply-to')).firstOrNull, body: body);
}

/// The Message-IDs of a `References` or `In-Reply-To` header, in order.
List<String> _ids(String header) => [for (final m in RegExp('<[^<>]+>').allMatches(header)) m[0]!];

DateTime? _internalDate(MimeMessage mime) => switch (mime.internalDate) {
  final d? => DateCodec.decodeDate(d),
  null => null,
};

/// The HTML part if there is one, else the plain text one, with the attachments (ids are the MIME part numbers).
// ponytail: whatever the sync fetched in full; on-demand bodies and attachment downloads come with T4 (#164).
MessageBody _body(MimeMessage mime) {
  final attachments = [
    for (final info in mime.findContentInfo())
      Attachment(id: info.fetchId, name: info.fileName ?? '', size: info.size ?? 0, mimeType: info.mediaType?.text),
  ];
  if (_textPart(mime, MediaSubtype.textHtml)?.decodeContentText() case final html?) {
    return MessageBody(html, BodyKind.html, attachments: attachments);
  }
  return MessageBody(
    _textPart(mime, MediaSubtype.textPlain)?.decodeContentText() ?? '',
    BodyKind.testo,
    attachments: attachments,
  );
}

/// The first [type] part of [p], depth first, outside the attachments: an attached `report.html` is not the text.
MimePart? _textPart(MimePart p, MediaSubtype type) {
  if (p.getHeaderContentDisposition()?.disposition == ContentDisposition.attachment) return null;
  final parts = p.parts;
  if (parts == null || parts.isEmpty) return p.mediaType.sub == type ? p : null;
  for (final c in parts) {
    if (_textPart(c, type) case final found?) return found;
  }
  return null;
}
