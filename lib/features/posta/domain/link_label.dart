import 'package:html/dom.dart' show Element;

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

/// Tags that restyle or reorder the text they hold. (`font` is fine inside the link, with no attribute, but not
/// above it: its `color` could hide the label.)
const _alters = {'font', 'bdi', 'bdo', 'marquee'};

/// Format and control characters (bidi overrides, zero-width, soft hyphen) can reorder or pad a label.
final _invisible = RegExp(r'\p{Cf}|(?![\t\n\r\f])\p{Cc}', unicode: true);

/// The only elements a trusted label may hold, with no attribute: inline, they cannot break or hide the text.
const _inline = {'b', 'strong', 'i', 'em', 'u', 'span', 'font', 'small', 'big'};

/// The visible label of the link [a], or [unverifiableText] when anything could make it differ from what is shown
/// (allowlist, fail closed, hence a Dialog): [styled] (the document has a `<style>` or a stylesheet `<link>`), a
/// `style`/`dir` or other attribute outside [_neutral] on the link or an ancestor, an empty label, and inside the
/// link anything but text and attribute-less inline elements ([_inline]; no `br`, `img`...). Plain nested tags
/// (`<b>`) keep their text, joined without a gap: they cannot break the line.
String linkLabel(Element a, {required bool styled}) {
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
  return hideable ? unverifiableText : a.text;
}
