import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parse;

/// The texts of every link that goes to [url]: by exact `href` and by the URL itself once normalised
/// (`https://a.example` and `https://a.example/` are one destination), so a deceptive label cannot hide among honest ones.
Iterable<String> textsOf(Map<String, List<String>> links, String url) {
  String? key(String s) {
    final u = Uri.tryParse(s);
    return u == null ? null : (u.hasAuthority && u.path.isEmpty ? u.replace(path: '/') : u).toString();
  }

  final wanted = key(url);
  return [
    for (final e in links.entries)
      if (e.key == url || key(e.key) == wanted) ...e.value,
  ];
}

/// Stands for the text of a link whose visible label cannot be told from its markup.
const unverifiableText = '\u0000unverifiable';

/// Attributes that change nothing about how text shows (layout ones included).
const _neutral = {
  'id',
  'class',
  'lang',
  'align',
  'width',
  'height',
  'valign',
  'border',
  'cellpadding',
  'cellspacing',
  'role',
};

/// Tags that restyle or reorder the text they hold.
const _alters = {'font', 'bdi', 'bdo', 'marquee'};

/// Format and control characters (bidi overrides, zero-width, soft hyphen) can reorder or pad a label.
final _invisible = RegExp(r'\p{Cf}|(?![\t\n\r\f])\p{Cc}', unicode: true);

/// The only elements a trusted label may hold, with no attribute: inline, they cannot break or hide the text.
const _inline = {'b', 'strong', 'i', 'em', 'u', 'span', 'font', 'small', 'big'};

/// The visible texts of the links of [html], by `href`: what a tap on that URL claims to open. CSS cannot be judged
/// here, so a label is trusted only when nothing can alter it (allowlist, fail closed; else [unverifiableText], hence
/// a Dialog): no `<style>` or stylesheet `<link>` in the document, no `style` or `dir` on the link or an ancestor, a
/// non-empty label, and inside the link only text and attribute-less inline elements ([_inline]; no `br`, `img`...).
/// Plain nested tags (`<b>`) keep their text, joined without a gap: they cannot break the line.
Map<String, List<String>> linkTexts(String html) {
  final doc = parse(html);
  final styled = doc.querySelector('style, link[rel~=stylesheet]') != null;
  final out = <String, List<String>>{};
  for (final a in doc.querySelectorAll('a[href]')) {
    // Anything above the link that can restyle, hide or reorder it: an attribute outside `_neutral`, or a presentational tag.
    var altered = false;
    for (Element? e = a.parent; e != null; e = e.parent) {
      altered |= _alters.contains(e.localName) || e.attributes.keys.any((k) => !_neutral.contains(k));
    }
    altered |= a.attributes.keys.any(
      (k) => !_neutral.contains(k) && !const {'href', 'target', 'rel', 'title'}.contains(k),
    );
    final hideable =
        styled ||
        altered ||
        _invisible.hasMatch(a.text) ||
        a.text.trim().isEmpty ||
        a.querySelectorAll('*').any((e) => !_inline.contains(e.localName) || e.attributes.isNotEmpty);
    (out[a.attributes['href']!] ??= []).add(hideable ? unverifiableText : a.text);
  }
  return out;
}
