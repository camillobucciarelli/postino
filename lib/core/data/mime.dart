import 'package:enough_mail/enough_mail.dart' show MailAddress, MessageBuilder;

import '../domain/html_text.dart';
import '../domain/mailbox.dart';
import '../domain/message.dart';

/// The biggest message Gmail sends: 35 MB of RFC 5322 text (`messages.send`).
// ponytail: the limit is Gmail's; per-Provider limits when other adapters arrive.
const gmailSendLimitBytes = 36700160;

/// The raw RFC 5322 text of [m]: multipart/alternative, the plain text read off the HTML, dated [date].
/// Rendered once: the same text goes to the Bozza and to the send.
String renderMime(OutgoingMessage m, DateTime date) {
  MailAddress address(String s) {
    final p = parseMailbox(s);
    return MailAddress(p.name, p.address);
  }

  return (MessageBuilder.prepareMultipartAlternativeMessage(
          plainText: htmlText(m.body),
          htmlText: m.body,
        )
        ..from = [address(m.from)]
        ..to = m.to.map(address).toList()
        ..cc = m.cc.map(address).toList()
        ..bcc = m.bcc.map(address).toList()
        ..subject = m.subject
        ..messageId = m.messageId
        ..date = date)
      .buildMimeMessage()
      .renderMessage();
}
