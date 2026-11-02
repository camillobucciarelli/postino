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
