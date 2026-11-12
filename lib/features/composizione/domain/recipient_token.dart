import '../../../core/domain/contact.dart';
import '../../../core/domain/mailbox.dart';

/// Where the address being written starts in a recipients field: after its last comma outside quotes and `<...>`.
int recipientTokenStart(String text) {
  var start = 0;
  var quoted = false;
  var angle = false;
  var escaped = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (escaped) {
      escaped = false;
    } else if (ch == r'\' && quoted) {
      escaped = true;
    } else if (ch == '"') {
      quoted = !quoted;
    } else if (!quoted && ch == '<') {
      angle = true;
    } else if (!quoted && ch == '>') {
      angle = false;
    } else if (ch == ',' && !quoted && !angle) {
      start = i + 1;
    }
  }
  return start;
}

/// The address being written in [text], trimmed: what the Contatti are suggested for.
String recipientToken(String text) => text.substring(recipientTokenStart(text)).trim();

/// [text] with the address being written replaced by [c] and a `, ` after it, ready for the next one.
String completeRecipient(String text, Contact c) {
  final start = recipientTokenStart(text);
  return '${text.substring(0, start)}${start > 0 ? ' ' : ''}${formatMailbox(c)}, ';
}
