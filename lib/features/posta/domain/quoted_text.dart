import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import '../../../core/domain/html_text.dart';
import 'safe_html.dart' show dropHeadContent;

/// A message body split for the Conversazione (ThreadView): what it says, its signature and the text it
/// quotes. Every part is in the body's own format (cleaned HTML or plain text); [original] is the whole.
class BodyParts {
  const BodyParts({
    required this.original,
    required this.body,
    required this.bodyVisible,
    this.signature,
    this.quote,
  });

  final String original;
  final String body;

  /// [body] shows some text or an image: folding the rest never leaves the message empty.
  final bool bodyVisible;
  final String? signature;
  final String? quote;

  /// The signature normalized: the same one in two messages compares equal.
  String? get signatureKey {
    final s = signature;
    if (s == null) return null;
    final text = _looksLikeHtml(s) ? htmlText(s) : s;
    final key = text
        .replaceFirst(RegExp(r'^\s*--[ \t]*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return key.isEmpty ? null : key;
  }
}

const _escape = HtmlEscape(HtmlEscapeMode.element);

bool _looksLikeHtml(String s) => s.trimLeft().startsWith('<');

/// What a message shows: [body], then [signature] (in `body-quote`, `ink-muted`), then [folded] behind «…»:
/// the quote, and the signature too when [repeated] (already seen earlier in the Conversazione).
/// When folding would leave nothing visible, nothing is folded: [body] is the whole message.
typedef FoldedBody = ({String body, String? signature, String? folded});

FoldedBody foldBody(BodyParts p, {required bool repeated}) {
  final shownSignature = repeated ? null : p.signature;
  final folded = [?(repeated ? p.signature : null), ?p.quote];
  if (folded.isEmpty && shownSignature == null) {
    return (body: p.original, signature: null, folded: null);
  }
  if (!p.bodyVisible && shownSignature == null) {
    return (body: p.original, signature: null, folded: null);
  }
  return (
    body: p.body,
    signature: shownSignature,
    folded: folded.isEmpty ? null : folded.join('\n'),
  );
}

/// For each signature key, oldest message first: true when the same signature already appeared before.
List<bool> repeatedSignatures(Iterable<String?> keys) {
  final seen = <String>{};
  return [for (final k in keys) k != null && !seen.add(k)];
}

/// «---------- Forwarded message ---------», «Messaggio inoltrato», Apple's «Begin forwarded message».
final _forward = RegExp(
  r'-{3,}\s*(forwarded message|messaggio inoltrato)\s*-{3,}'
  r'|begin forwarded message|inizio messaggio inoltrato',
  caseSensitive: false,
);

/// Outlook's reply header says Subject/Oggetto; a forward's starts with FW:, Fwd: or I:.
final _outlookForward = RegExp(
  r'(subject|oggetto)\s*:\s*(fw|fwd|i|inoltro)\s*:',
  caseSensitive: false,
);

const quoteSelectors = [
  '.gmail_quote', // Gmail, its gmail_attr header inside
  '.gmail_attr', // a Gmail header left outside its quote
  '.moz-cite-prefix', // Thunderbird's header, before its blockquote
  'blockquote[type=cite]', // Apple Mail, Thunderbird
  '#divRplyFwdMsg', // Outlook: it and all that follows
  '#appendonsend',
  '.yahoo_quoted',
];

const signatureSelectors = [
  '.gmail_signature',
  '.moz-signature',
  '#Signature', // Outlook
];

/// Splits a cleaned HTML body ([prepareHtml]): the last quote of the main clients and the signature.
/// A forward is never a quote.
BodyParts splitHtml(String html) {
  final doc = parse(html);
  final root = doc.body;
  if (root == null) {
    return BodyParts(original: html, body: html, bodyVisible: true);
  }
  dropHeadContent(doc);
  final head = doc.head?.innerHtml ?? '';
  final quote = _takeQuote(root);
  final signature = _takeSignature(root);
  String part(List<Node> nodes) =>
      '$head${nodes.map((n) => switch (n) {
        Element() => n.outerHtml,
        Text() => _escape.convert(n.data),
        _ => n.text,
      }).join()}';
  return BodyParts(
    original: html,
    body: doc.outerHtml,
    bodyVisible: _visible(root),
    signature: signature == null ? null : part(signature),
    quote: quote == null ? null : part(quote),
  );
}

/// Takes the quote out of [root]: the outermost candidate, the last one if there are several
/// (an inline reply keeps what follows it); for Outlook everything after it too.
List<Node>? _takeQuote(Element root) {
  final all = root.querySelectorAll(quoteSelectors.join(','));
  final set = all.toSet();
  final candidates = [
    for (final e in all)
      if (!_hasAncestorIn(e, set)) e,
  ];
  if (candidates.isEmpty) return null;
  final outlook = candidates
      .where((e) => e.id == 'divRplyFwdMsg' || e.id == 'appendonsend')
      .firstOrNull;
  final last = candidates.last;
  // A header beside its quote (Thunderbird's cite prefix, a Gmail attribution) goes with it.
  final previous = candidates.length > 1
      ? candidates[candidates.length - 2]
      : null;
  final start =
      previous != null &&
          previous.parent == last.parent &&
          (previous.classes.contains('moz-cite-prefix') ||
              previous.classes.contains('gmail_attr'))
      ? previous
      : last;
  final from = outlook ?? start;
  final nodes = outlook != null
      ? _fromHere(outlook, root)
      : _siblingsUntil(start, last);
  final text = nodes.map((n) => n.text ?? '').join(' ');
  final header = text.length > 600 ? text.substring(0, 600) : text;
  if (_forward.hasMatch(header) ||
      _forward.hasMatch(_previousText(from)) ||
      (outlook != null && _outlookForward.hasMatch(header))) {
    return null;
  }
  for (final n in nodes) {
    n.remove();
  }
  return nodes;
}

bool _hasAncestorIn(Element e, Set<Element> set) {
  for (var p = e.parent; p != null; p = p.parent) {
    if (set.contains(p)) return true;
  }
  return false;
}

/// [first] and its following siblings up to [last] (the same node when they are one).
List<Node> _siblingsUntil(Element first, Element last) {
  if (first == last || first.parent != last.parent) return [last];
  final siblings = first.parent!.nodes;
  return siblings.sublist(siblings.indexOf(first), siblings.indexOf(last) + 1);
}

/// [start] and everything after it in document order, up to [root]: Outlook's quote runs to the end.
List<Node> _fromHere(Element start, Element root) {
  final out = <Node>[];
  Node? n = start;
  var first = true;
  while (n != null && n != root) {
    final parent = n.parent!;
    final siblings = parent.nodes;
    out.addAll(siblings.sublist(siblings.indexOf(n) + (first ? 0 : 1)));
    first = false;
    n = parent;
  }
  return out;
}

/// The text just before [e]: a forward header often sits outside the quote («Begin forwarded message:»).
String _previousText(Element e) {
  final siblings = e.parent?.nodes;
  if (siblings == null) return '';
  final text = siblings
      .take(siblings.indexOf(e))
      .map((n) => n.text ?? '')
      .join(' ');
  return text.length > 200 ? text.substring(text.length - 200) : text;
}

/// Takes the first signature out of [root], with Gmail's «-- » prefix before it. One inside a quote
/// left in place (a forward) is the original sender's, not the author's.
List<Node>? _takeSignature(Element root) {
  final quotes = root.querySelectorAll(quoteSelectors.join(',')).toSet();
  final sig = root
      .querySelectorAll(signatureSelectors.join(','))
      .where((e) => !_hasAncestorIn(e, quotes))
      .firstOrNull;
  if (sig == null) return null;
  final prefix = sig.parent?.querySelector('.gmail_signature_prefix');
  prefix?.remove();
  sig.remove();
  return [sig];
}

bool _visible(Element root) =>
    root.text.trim().isNotEmpty || root.querySelector('img') != null;

/// A plain text body: the trailing block of `>` lines with the «Il giorno … ha scritto:» / «On … wrote:»
/// line before it, and the signature after a `-- ` line. A forward is never a quote.
BodyParts splitText(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  var end = lines.length;
  var quoteStart = end;
  if (!_forward.hasMatch(text)) {
    var i = end - 1;
    while (i >= 0 && lines[i].trim().isEmpty) {
      i--;
    }
    if (i >= 0 && lines[i].trimLeft().startsWith('>')) {
      var start = i;
      for (var j = i; j >= 0; j--) {
        final l = lines[j].trimLeft();
        if (l.startsWith('>')) {
          start = j;
        } else if (l.isNotEmpty) {
          break;
        }
      }
      quoteStart = _withHeader(lines, start);
    }
  }
  final quote = quoteStart < end
      ? lines.sublist(quoteStart).join('\n').trim()
      : null;
  final before = lines.sublist(0, quoteStart);
  final dash = before.lastIndexWhere((l) => l == '-- ' || l == '--');
  final body = (dash < 0 ? before : before.sublist(0, dash)).join('\n').trim();
  final signature = dash < 0 ? null : before.sublist(dash).join('\n').trim();
  return BodyParts(
    original: text.trim(),
    body: body,
    bodyVisible: body.isNotEmpty,
    signature: signature,
    quote: quote,
  );
}

/// «On Mon, 26 Oct 2026 at 09:15, Ada `<ada@x.it>` wrote:», maybe wrapped on two lines, maybe a blank line
/// before the quote: where the quote starts, header included.
int _withHeader(List<String> lines, int quoteStart) {
  var i = quoteStart - 1;
  while (i >= 0 && lines[i].trim().isEmpty) {
    i--;
  }
  if (i < 0) return quoteStart;
  for (final from in [i, i - 1]) {
    if (from < 0) break;
    final header = lines.sublist(from, i + 1).join(' ').trim();
    if (_header.hasMatch(header)) return from;
  }
  return quoteStart;
}

final _header = RegExp(
  r'^(on\b.*\bwrote|il giorno\b.*\bha scritto)\s*:$',
  caseSensitive: false,
);
