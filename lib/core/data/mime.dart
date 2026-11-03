import 'package:enough_mail/enough_mail.dart'
    show MailAddress, MediaType, MessageBuilder;

import '../domain/html_text.dart';
import '../domain/mailbox.dart';
import '../domain/message.dart';
import '../domain/result.dart';

/// The biggest message Gmail sends: 35 MB of RFC 5322 text (`messages.send`).
// ponytail: the limit is Gmail's; per-Provider limits when other adapters arrive.
const gmailSendLimitBytes = 36700160;

/// The raw RFC 5322 text of [m], dated [date]: multipart/alternative, the plain text read off the HTML,
/// with In-Reply-To and References of a reply; inside a multipart/mixed with [attachments] (the bytes of
/// [OutgoingMessage.attachments], in order) when a forward carries any (#37).
/// Rendered once: the same text goes to the Bozza and to the send.
String renderMime(
  OutgoingMessage m,
  DateTime date, [
  List<AttachmentBytes> attachments = const [],
]) {
  MailAddress address(String s) {
    final p = parseMailbox(s);
    return MailAddress(p.name, p.address);
  }

  final text = htmlText(m.body);
  final MessageBuilder builder;
  if (m.attachments.isEmpty) {
    builder = MessageBuilder.prepareMultipartAlternativeMessage(
      plainText: text,
      htmlText: m.body,
    );
  } else {
    builder = MessageBuilder.prepareMultipartMixedMessage()
      ..addMultipartAlternative(plainText: text, htmlText: m.body);
    for (final (i, f) in m.attachments.indexed) {
      final a = f.attachment;
      builder.addBinary(
        attachments[i],
        MediaType.fromText(a.mimeType ?? 'application/octet-stream'),
        filename: a.name.isEmpty ? null : a.name,
      );
    }
  }
  builder
    ..from = [address(m.from)]
    ..to = m.to.map(address).toList()
    ..cc = m.cc.map(address).toList()
    ..bcc = m.bcc.map(address).toList()
    ..subject = m.subject
    ..messageId = m.messageId
    ..date = date;
  if (m.inReplyTo case final id?) builder.setHeader('In-Reply-To', id);
  if (m.references.isNotEmpty) {
    builder.setHeader('References', m.references.join(' '));
  }
  return builder.buildMimeMessage().renderMessage();
}

/// [renderMime] after downloading the forwarded attachments of [m] through [fetch]; the first failed
/// download is the [Err].
Future<Result<String>> renderMimeFetching(
  OutgoingMessage m,
  DateTime date,
  Future<Result<AttachmentBytes>> Function(
    String messageId,
    String attachmentId,
  )
  fetch,
) async {
  final bytes = <AttachmentBytes>[];
  for (final f in m.attachments) {
    switch (await fetch(f.sourceMessageId, f.attachment.id)) {
      case Ok(:final value):
        bytes.add(value);
      case Err(:final failure):
        return Err(failure);
    }
  }
  return Ok(renderMime(m, date, bytes));
}
