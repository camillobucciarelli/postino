// HTML fixtures split across lines: the tags are the separators, no whitespace is wanted between fragments.
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'package:html/parser.dart' show parse;

/// The faithful HTML of a message for «Vedi originale» (ADR 0007): the sender's HTML under a
/// Content-Security-Policy that allows no script, no frame, no font and no stylesheet link. Images: only `data:`,
/// plus `https:`/`http:` when [allowRemote] (the same rules as the Conversazione: shown for the message or a Mittente fidato).
/// What a CSP does not stop is taken out: `<base>`, `<link>` (prefetch, preconnect, stylesheets) and every
/// `<meta http-equiv>` (a `refresh` would navigate with no tap); DNS prefetch and the Referer are switched off.
String originalDocument(String html, {required bool allowRemote}) {
  final doc = parse(html);
  for (final e in doc.querySelectorAll('base, link, meta[http-equiv]').toList()) {
    e.remove();
  }
  // A `target` opens a link in a new frame or window, which the WebView reports as a subframe: every tap is a main-frame one.
  for (final e in doc.querySelectorAll('a[target], area[target]')) {
    e.attributes.remove('target');
  }
  final img = allowRemote ? 'data: https: http:' : 'data:';
  return '<meta http-equiv="x-dns-prefetch-control" content="off">'
      '<meta name="referrer" content="no-referrer">'
      '<meta http-equiv="Content-Security-Policy" '
      "content=\"default-src 'none'; form-action 'none'; img-src $img; style-src 'unsafe-inline'\">${doc.outerHtml}";
}
