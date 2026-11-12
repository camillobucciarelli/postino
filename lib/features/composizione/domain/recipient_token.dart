import '../../../core/domain/contact.dart';
import '../../../core/domain/mailbox.dart';

/// The address the caret is in, in a recipients field: between the commas (outside quotes and `<...>`) around
/// [caret]; null for a [caret] outside [text] (no caret, a selection).
({int start, int end})? recipientRange(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final commas = mailboxSeparators(text);
  final start = (commas.lastWhere((i) => i < caret, orElse: () => -1)) + 1;
  final end = commas.firstWhere((i) => i >= caret, orElse: () => text.length);
  return (start: start, end: end);
}

/// The address the caret is in, trimmed: what the Contatti are suggested for; empty without a caret.
String recipientToken(String text, int caret) {
  final r = recipientRange(text, caret);
  return r == null ? '' : text.substring(r.start, r.end).trim();
}

/// [text] with the address the caret is in replaced by [c] and a `, ` after it, and the caret right after that,
/// ready for the next one; the addresses after it stay. Null without a caret.
({String text, int caret})? completeRecipient(String text, int caret, Contact c) {
  final r = recipientRange(text, caret);
  if (r == null) return null;
  final head = '${text.substring(0, r.start)}${r.start > 0 ? ' ' : ''}${formatMailbox(c)}, ';
  // The next address keeps its place after the new «, ».
  final rest = text.substring(r.end).replaceFirst(RegExp(r'^,\s*'), '');
  return (text: '$head$rest', caret: head.length);
}
