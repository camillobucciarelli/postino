import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

const _blocks = {
  'address', 'blockquote', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', //
  'li', 'ol', 'p', 'pre', 'table', 'tr', 'ul',
};

/// The text of an HTML fragment as it reads: a `<br>` or a block boundary is a line break.
String htmlText(String html) {
  final out = StringBuffer();
  void walk(Node n) {
    if (n is Text) return out.write(n.data);
    if (n is! Element) return n.nodes.forEach(walk);
    final block = _blocks.contains(n.localName);
    if (n.localName == 'br' || block) out.write('\n');
    n.nodes.forEach(walk);
    if (block) out.write('\n');
  }

  final doc = parse(html);
  walk(doc.body ?? doc);
  return '$out';
}

/// The body as a list shows it: no tags, spaces compressed, at most 120 characters.
String listSnippet(String html) {
  final text = htmlText(html).replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > 120 ? text.substring(0, 120) : text;
}

const _escape = HtmlEscape(HtmlEscapeMode.element);

/// Plain text as HTML: a paragraph per blank-line block, `<br>` for the other line breaks, the text escaped.
String plainToHtml(String text) => text.trim().isEmpty
    ? '<p></p>'
    : [
        for (final p in text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n')))
          if (p.trim().isNotEmpty)
            '<p>${_escape.convert(p.trim()).replaceAll('\n', '<br>')}</p>',
      ].join();
