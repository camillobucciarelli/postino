import 'dart:convert' show htmlEscape;

import 'mailbox.dart';
import 'message.dart';

/// Rispondi, Rispondi a tutti and Inoltra (#37): the [OutgoingMessage] the composer starts from, built off
/// the original message. Pure: the date label comes in already formatted by the presentation.

final _prefixes = RegExp(r'^\s*(re|r|fwd|fw|i)\s*:', caseSensitive: false);

/// [subject] without its leading `Re:`, `R:`, `Fwd:`, `Fw:` and `I:` prefixes (any case, repeated), trimmed.
String _bare(String subject) {
  var s = subject;
  for (
    var m = _prefixes.firstMatch(s);
    m != null;
    m = _prefixes.firstMatch(s)
  ) {
    s = s.substring(m.end);
  }
  return s.trim();
}

/// `Re: ` + the subject stripped of every leading reply/forward prefix (`Re:`, `R:`, `Fwd:`, `Fw:`, `I:`,
/// any case, also repeated as in `RE: R: x`): a prefix is never doubled, and a reply to a forward is
/// `Re: x`. An empty subject gives `Re:`.
String replySubject(String subject) => 'Re: ${_bare(subject)}'.trim();

/// `Fwd: ` + the subject stripped as in [replySubject]; an empty subject gives `Fwd:`.
String forwardSubject(String subject) => 'Fwd: ${_bare(subject)}'.trim();

String _from(Message m) => formatMailbox((name: m.fromName, address: m.from));

/// [mailboxes] without those whose address is in [seen] (case-insensitive) and without duplicates,
/// first occurrence first; the addresses kept are added to [seen].
List<String> _unique(Iterable<String> mailboxes, Set<String> seen) => [
  for (final m in mailboxes)
    if (seen.add(parseMailbox(m).address.toLowerCase())) m,
];

/// Who a reply goes to: the `Reply-To` mailbox, else the sender; for a message the Account itself
/// ([self]) sent, its recipients.
List<String> replyRecipients(Message m, {required String self}) {
  final to = _unique([m.replyTo ?? _from(m)], {self.toLowerCase()});
  return to.isEmpty ? _unique(m.to, {}) : to;
}

/// Who a reply to all goes to: `to` is the `Reply-To` (else the sender) and the original To, `cc` the
/// original Cc, both without the Account's own address ([self]) and without duplicates by address
/// (first occurrence wins, a mailbox in both stays in `to`). When [self] empties `to` (a reply to one's
/// own message), `to` is the original To.
({List<String> to, List<String> cc}) replyAllRecipients(
  Message m, {
  required String self,
}) {
  final seen = {self.toLowerCase()};
  var to = _unique([m.replyTo ?? _from(m), ...m.to], seen);
  if (to.isEmpty) to = _unique(m.to, seen..clear());
  return (to: to, cc: _unique(m.cc, seen));
}

String _esc(String s) => htmlEscape.convert(s);

/// `Nome &lt;indirizzo&gt;`, or the bare address, escaped.
String _who(Message m) {
  final name = m.fromName;
  return name == null ? _esc(m.from) : '${_esc(name)} &lt;${_esc(m.from)}&gt;';
}

/// The original message quoted under a reply, Gmail-style: an attribution line, then the original HTML
/// in a `<blockquote>`. [bodyHtml] is HTML already (a plain-text body goes through [plainToHtml] first).
String quoteHtml(
  Message original, {
  required String dateLabel,
  required String bodyHtml,
}) =>
    '<div class="postino-quote"><p>Il giorno ${_esc(dateLabel)}, ${_who(original)} '
    'ha scritto:</p><blockquote>$bodyHtml</blockquote></div>';

/// The original message under a forward, Gmail-style: the `---------- Messaggio inoltrato ----------`
/// block with Da, Data, Oggetto, A (and Cc when there is one), then the original HTML, not quoted.
String forwardHeaderHtml(
  Message original, {
  required String dateLabel,
  required String bodyHtml,
}) {
  final lines = [
    'Da: ${_who(original)}',
    'Data: ${_esc(dateLabel)}',
    'Oggetto: ${_esc(original.subject)}',
    'A: ${_esc(original.to.join(', '))}',
    if (original.cc.isNotEmpty) 'Cc: ${_esc(original.cc.join(', '))}',
  ].join('<br>');
  return '<div class="postino-forward"><p>---------- Messaggio inoltrato ----------'
      '<br>$lines</p>$bodyHtml</div>';
}

/// An empty paragraph for the new text, above the quoted original.
const _blank = '<p><br></p>';

/// The reply ([all]: to everyone) to [original] from the Account [self], with the fresh [messageId]:
/// threaded by In-Reply-To, References (the original's chain plus its id, no duplicates) and the
/// original Conversazione.
OutgoingMessage buildReply({
  required Message original,
  required String originalHtml,
  required String self,
  required String messageId,
  required bool all,
  required String dateLabel,
}) {
  final (:to, :cc) = all
      ? replyAllRecipients(original, self: self)
      : (to: replyRecipients(original, self: self), cc: const <String>[]);
  final id = original.messageId;
  return OutgoingMessage(
    messageId: messageId,
    from: self,
    to: to,
    cc: cc,
    subject: replySubject(original.subject),
    body:
        _blank +
        quoteHtml(original, dateLabel: dateLabel, bodyHtml: originalHtml),
    inReplyTo: id.isEmpty ? null : id,
    references: {...original.references, if (id.isNotEmpty) id}.toList(),
    conversationId: original.conversationId,
  );
}

/// The forward of [original] from the Account [self], with the fresh [messageId]: no recipients, the
/// original's [attachments] taken over, not threaded.
OutgoingMessage buildForward({
  required Message original,
  required String originalHtml,
  required String self,
  required String messageId,
  required String dateLabel,
  required List<Attachment> attachments,
}) => OutgoingMessage(
  messageId: messageId,
  from: self,
  to: const [],
  subject: forwardSubject(original.subject),
  body:
      _blank +
      forwardHeaderHtml(original, dateLabel: dateLabel, bodyHtml: originalHtml),
  attachments: [
    for (final a in attachments) ForwardedAttachment(original.id, a),
  ],
);
