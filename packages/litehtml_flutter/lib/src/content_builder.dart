import 'dart:ui';

import 'package:flutter/painting.dart' show TextStyle;

import 'bindings.dart';
import 'litehtml_content.dart';

/// Costruisce un [LitehtmlContent] dagli eventi di `lh_export`, in ordine di documento.
///
/// Le parole contigue con lo stesso font diventano un [TextFragment]; i nodi spezzano il testo ai confini di blocco,
/// di titolo e di link, così ogni link è un nodo a sé (attivabile) e un paragrafo non lo inghiotte.
///
/// Un'immagine senza `src` (segnaposto) ha per nome [_blockedLabel] seguito dall'`alt`, se c'è.
class ContentBuilder(final TextStyle Function(int font) _styleOf, [final String? _blockedLabel]) {
  final _fragments = <_Fragment>[];
  final _nodes = <ContentNode>[];
  final _open = <({int kind, int level, String attr})>[];
  var _separator = _none;
  _Node? _node;
  var _nodeSpace = false;

  static const _none = -1;

  void text(String text, int font, Rect rect) {
    _addFragment(text, font, rect);
    _addToNode(text, rect);
  }

  void separator(int kind) {
    if (kind > _separator) _separator = kind;
    // Un a capo chiude il nodo, tranne dentro un link: un link su più righe resta una sola fermata di Tab.
    if (kind == lhSepLine && !_open.any((o) => o.kind == lhNodeLink)) {
      _flush();
    } else {
      _nodeSpace = true;
    }
  }

  void open(int kind, int level, String attr, Rect box) {
    if (kind == lhNodeImage) {
      final blocked = _blockedLabel;
      _image(level == 1 && blocked != null ? [blocked, attr].where((l) => l.isNotEmpty).join(': ') : attr, box);
    } else {
      _flush();
    }
    _open.add((kind: kind, level: level, attr: attr));
  }

  void close() {
    if (_open.removeLast().kind != lhNodeImage) _flush();
  }

  LitehtmlContent build() {
    _flush();
    return LitehtmlContent(fragments: [for (final f in _fragments) f.toFragment(_styleOf(f.font))], nodes: _nodes);
  }

  void _addFragment(String text, int font, Rect rect) {
    final last = _fragments.isEmpty ? null : _fragments.last;
    if (last != null &&
        _separator == _none &&
        last.font == font &&
        last.rect.top == rect.top &&
        last.rect.height == rect.height &&
        (rect.left - last.rect.right).abs() < 0.5) {
      last
        ..text.write(text)
        ..rect = last.rect.expandToInclude(rect);
      return;
    }
    final separator = switch (_separator) {
      _ when last == null => '',
      lhSepLine => '\n',
      lhSepSpace when !text.startsWith(' ') && !last.endsWithSpace => ' ',
      _ => '',
    };
    _fragments.add(_Fragment(StringBuffer(text), font, rect, separator));
    _separator = _none;
  }

  void _addToNode(String text, Rect rect) {
    final node = _node ??= _newNode();
    if (text.trim().isEmpty) {
      _nodeSpace = true;
    } else {
      if (_nodeSpace && node.label.isNotEmpty) node.label.write(' ');
      node.label.write(text);
      _nodeSpace = false;
    }
    node.add(rect);
  }

  void _image(String alt, Rect box) {
    final inLink = _open.any((o) => o.kind == lhNodeLink);
    // Un'immagine in un link gli dà il nome; fuori, `alt` vuoto o assente = decorativa.
    if (inLink) {
      _addToNode(alt.isEmpty ? ' ' : alt, box);
      return;
    }
    _flush();
    final label = _collapse(alt);
    if (label.isNotEmpty && !box.isEmpty) _nodes.add(ContentNode(label: label, rects: [box], image: true));
  }

  _Node _newNode() {
    var level = 0;
    String? href;
    for (final o in _open.reversed) {
      if (o.kind == lhNodeHeading && level == 0) level = o.level;
      if (o.kind == lhNodeLink) href ??= o.attr;
    }
    return _Node(level, href);
  }

  void _flush() {
    final node = _node;
    _node = null;
    _nodeSpace = false;
    if (node == null || node.rects.isEmpty) return;
    var label = _collapse(node.label.toString());
    final href = node.href;
    // Link senza testo né alt: il dominio, come fanno i lettori di schermo dei browser.
    if (label.isEmpty && href != null) label = _hostOf(href);
    if (label.isEmpty) return;
    _nodes.add(ContentNode(label: label, rects: node.rects, headingLevel: node.level, href: href));
  }

  static String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _hostOf(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) return href;
    return uri.host.isNotEmpty ? uri.host : (uri.path.isNotEmpty ? uri.path : href);
  }
}

class _Fragment(final StringBuffer text, final int font, var Rect rect, final String separator) {
  bool get endsWithSpace => text.toString().endsWith(' ');

  TextFragment toFragment(TextStyle style) => TextFragment(
    text: text.toString(),
    offset: rect.topLeft,
    width: rect.width,
    height: rect.height,
    style: style,
    separator: separator,
  );
}

class _Node(final int level, final String? href) {
  final label = StringBuffer();
  final rects = <Rect>[];

  /// Un box per riga: le parole contigue sulla stessa riga si uniscono.
  void add(Rect r) {
    if (rects.isNotEmpty) {
      final last = rects.last;
      if (last.top == r.top && last.bottom == r.bottom && r.left >= last.left && r.left - last.right < 1) {
        rects.last = last.expandToInclude(r);
        return;
      }
    }
    rects.add(r);
  }
}
