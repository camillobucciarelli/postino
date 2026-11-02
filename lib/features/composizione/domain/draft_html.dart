import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// The formats of #35: everything else is flattened to text on the way in and out.
const _inline = {'bold', 'italic', 'underline', 'strike', 'link'};
const _lists = {'bullet', 'ordered'};

/// The body of a Bozza as HTML (text/plain is the adapter's), with only the allowed formats.
String deltaToHtml(List<Map<String, dynamic>> ops) => QuillDeltaToHtmlConverter(
  _clean(ops),
  ConverterOptions.forEmail(),
).convert();

/// The HTML of a Bozza (ours or another client's) as Delta ops, the adjacent runs not merged
/// (quill's Document does it); empty HTML is the empty document.
List<Map<String, dynamic>> htmlToDelta(String html) {
  final ops = _clean(HtmlToDelta().convert(html).toJson());
  // The parser closes with a newline of its own, one too many after a block that already ends with one.
  if (ops.length > 1 &&
      ops.last['insert'] == '\n' &&
      ops.last['attributes'] == null &&
      (ops[ops.length - 2]['insert'] as String).endsWith('\n')) {
    ops.removeLast();
  }
  return ops.isEmpty
      ? [
          {'insert': '\n'},
        ]
      : ops;
}

/// Keeps the seven formats, drops the others; an embed (image) is dropped altogether.
List<Map<String, dynamic>> _clean(List<Map<String, dynamic>> ops) => [
  for (final op in ops)
    if (op['insert'] is String)
      {
        'insert': op['insert'],
        if (op['attributes'] case final Map a)
          if (<String, dynamic>{
                for (final MapEntry(:key, :value) in a.entries)
                  if (_inline.contains(key) ||
                      key == 'list' && _lists.contains(value))
                    key: value,
              }
              case final kept when kept.isNotEmpty)
            'attributes': kept,
      },
];
