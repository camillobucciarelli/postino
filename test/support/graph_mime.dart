// A message sent to the simulated Graph as base64 MIME (`sendMail`, `POST /me/messages`): what the mailbox keeps of it.
import 'dart:convert';

import 'package:enough_mail/enough_mail.dart' show MailAddress, MimeMessage;
import 'package:postino/core/domain/mailbox.dart';
import 'package:postino/core/domain/message.dart';

/// The MIME text inside a request body: base64 of the RFC 5322 text.
String graphMimeText(String requestBody) => utf8.decode(base64.decode(requestBody.trim()));

/// The message as the mailbox shows it: [id] is Graph's, [labelId] its folder's Etichetta; the HTML body comes out.
(Message, String) graphMessageFromMime(String raw, String id, String labelId, DateTime fallbackDate) {
  final mime = MimeMessage.parseFromText(raw);
  String address(MailAddress a) => formatMailbox((name: a.personalName, address: a.email));
  final from = mime.from!.first;
  return (
    Message(
      id: id,
      messageId: mime.getHeaderValue('message-id') ?? '',
      conversationId: 't-$id',
      labelIds: [labelId],
      isRead: true,
      isStarred: false,
      from: from.email,
      fromName: from.personalName,
      to: (mime.to ?? const []).map(address).toList(),
      cc: (mime.cc ?? const []).map(address).toList(),
      bcc: (mime.bcc ?? const []).map(address).toList(),
      subject: mime.decodeSubject() ?? '',
      snippet: '',
      date: mime.decodeDate() ?? fallbackDate,
    ),
    mime.decodeTextHtmlPart() ?? '',
  );
}
