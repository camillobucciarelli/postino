import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// The formats of #35, plus the blockquote of a reply (#37): everything else is flattened to text on the way in and out.
const _inline = {'bold', 'italic', 'underline', 'strike', 'link'};
const _lists = {'bullet', 'ordered'};

/// The body of a Bozza as HTML (text/plain is the adapter's), with only the allowed formats.
String deltaToHtml(List<Map<String, dynamic>> ops) =>
    QuillDeltaToHtmlConverter(_clean(ops), ConverterOptions.forEmail()).convert();

/// The HTML of a Bozza (ours or another client's) as Delta ops, the adjacent runs not merged
/// (quill's Document does it); empty HTML is the empty document. A `<blockquote>` (the Citazione of a
/// reply, #37) is converted apart and every one of its lines marked `blockquote`: the parser alone
/// collapses the blocks inside it into one line.
List<Map<String, dynamic>> htmlToDelta(String html) {
  final ops = _walk(parseFragment(html).nodes);
  return ops.isEmpty
      ? [
          {'insert': '\n'},
        ]
      : ops;
}

/// Each block (`<p>`, `<ul>`…) goes to the parser alone and a run of inline siblings together: the parser
/// glues sibling blocks onto one line. A container holding a blockquote is descended; a blockquote is
/// converted apart and marked.
// ponytail: nested blockquotes flatten into one level (the editor shows one depth); a list inside a quote
// becomes quoted lines. Enough for a Citazione; an `indent` level if people quote quotes.
List<Map<String, dynamic>> _walk(List<Node> nodes) {
  final out = <Map<String, dynamic>>[];
  final run = StringBuffer();
  void flush() {
    // The blank left between a run and a block is not content.
    if (run.isNotEmpty) out.addAll(_convert('$run'.trimRight()));
    run.clear();
  }

  for (final n in nodes) {
    if (n is Element && n.localName == 'blockquote') {
      flush();
      out.addAll(_quoted(_walk(n.nodes)));
    } else if (n is Element && (n.localName == 'div' || n.querySelector('blockquote') != null)) {
      // A div is only a wrapper (the parser would add a line after it).
      flush();
      out.addAll(_walk(n.nodes));
    } else if (n is Element && _blocks.contains(n.localName)) {
      flush();
      out.addAll(_convert(n.outerHtml));
    } else if (n is Element || n is Text && (n.data.trim().isNotEmpty || run.isNotEmpty)) {
      // A text goes back to the parser as HTML: `&lt;b&gt;` must stay literal. Blank between inlines is kept.
      run.write(n is Element ? n.outerHtml : _escape.convert((n as Text).data));
    }
  }
  flush();
  return out;
}

const _escape = HtmlEscape(HtmlEscapeMode.element);

const _blocks = {'p', 'ul', 'ol', 'pre', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table'};

/// Every line of [ops] as a blockquote line: a newline inside an insert is split out and marked.
List<Map<String, dynamic>> _quoted(List<Map<String, dynamic>> ops) => [
  for (final op in ops)
    for (final (i, part) in (op['insert'] as String).split('\n').indexed) ...[
      if (i > 0)
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      if (part.isNotEmpty)
        {
          'insert': part,
          if (op['attributes'] case final Map<String, dynamic> a when a.keys.any(_inline.contains))
            'attributes': {
              for (final MapEntry(:key, :value) in a.entries)
                if (_inline.contains(key)) key: value,
            },
        },
    ],
];

/// One chunk of HTML through the parser, cleaned.
List<Map<String, dynamic>> _convert(String html) {
  final ops = _clean(HtmlToDelta().convert(html).toJson());
  // The parser closes with a newline of its own, one too many after a block that already ends with one.
  if (ops.length > 1 &&
      ops.last['insert'] == '\n' &&
      ops.last['attributes'] == null &&
      (ops[ops.length - 2]['insert'] as String).endsWith('\n')) {
    ops.removeLast();
  }
  return ops;
}

/// Keeps the seven formats and the blockquote, drops the others; an embed (image) is dropped altogether.
List<Map<String, dynamic>> _clean(List<Map<String, dynamic>> ops) => [
  for (final op in ops)
    if (op['insert'] is String)
      {
        'insert': op['insert'],
        if (op['attributes'] case final Map<String, dynamic> a)
          if (<String, dynamic>{
                for (final MapEntry(:key, :value) in a.entries)
                  if (_inline.contains(key) || key == 'blockquote' || key == 'list' && _lists.contains(value))
                    key: value,
              }
              case final kept when kept.isNotEmpty)
            'attributes': kept,
      },
];
