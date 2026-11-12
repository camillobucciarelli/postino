import '../../../core/domain/contact.dart';
import '../../../core/domain/mailbox.dart';

/// Where the address being written starts in a recipients field: after its last comma outside quotes and `<...>`.
int recipientTokenStart(String text) => (mailboxSeparators(text).lastOrNull ?? -1) + 1;

/// The address being written in [text], trimmed: what the Contatti are suggested for.
String recipientToken(String text) => text.substring(recipientTokenStart(text)).trim();

/// [text] with the address being written replaced by [c] and a `, ` after it, ready for the next one.
String completeRecipient(String text, Contact c) {
  final start = recipientTokenStart(text);
  return '${text.substring(0, start)}${start > 0 ? ' ' : ''}${formatMailbox(c)}, ';
}
