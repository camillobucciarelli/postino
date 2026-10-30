import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import 'quoted_text.dart' show quoteSelectors, signatureSelectors;

/// An HTML body ready to render (ADR 0007): cleaned, remote resources blocked unless [prepareHtml]
/// was told otherwise. [blocked]: something remote was taken out. [width]: the widest fixed width
/// the HTML asks for, in px, if any (a 600px newsletter), so the view can scale it down.
typedef SafeHtml = ({String html, bool blocked, double? width});

/// What can run code or post data: gone with its content. A `form` keeps its content, without the form.
const _dropped = {
  'script',
  'iframe',
  'frame',
  'frameset',
  'object',
  'embed',
  'applet',
  'base',
  'input',
  'button',
  'select',
  'textarea',
};

/// Attributes that load a resource.
const _resourceAttributes = {'src', 'srcset', 'background', 'poster'};

/// Attributes that navigate: checked for `javascript:`.
const _urlAttributes = {
  'href',
  'src',
  'action',
  'formaction',
  'background',
  'poster',
  'xlink:href',
};

final _remote = RegExp(r'^\s*(https?:)?//', caseSensitive: false);

/// Some candidate of a `src` or `srcset` is remote.
final _anyRemote = RegExp(r'(^|,)\s*(https?:)?//', caseSensitive: false);
final _pixels = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(?:px)?\s*$');
final _cssUrl = RegExp(
  r'''url\(\s*(['"]?)([^'")]*)\1\s*\)''',
  caseSensitive: false,
);
final _cssImport = RegExp(
  r'''@import\s+(url\()?\s*['"]?\s*(https?:)?//[^;]*;?''',
  caseSensitive: false,
);
final _cssWidth = RegExp(
  r'(?:^|[;\s{])(?:min-)?width\s*:\s*(\d+(?:\.\d+)?)px',
  caseSensitive: false,
);

final _cellWidth = RegExp(r'^\s*(min-|max-)?width\s*:', caseSensitive: false);
final _tablePercent = RegExp(
  r'^\s*width\s*:\s*\d+(\.\d+)?%\s*(!important)?\s*$',
  caseSensitive: false,
);

/// A table with a row of 2+ cells of its own (nested tables don't count).
bool _multiColumn(Element table) => table
    .querySelectorAll('tr')
    .any(
      (r) =>
          _tableOf(r) == table &&
          r.children
                  .where((c) => c.localName == 'td' || c.localName == 'th')
                  .length >
              1,
    );

Element? _tableOf(Element e) {
  for (var p = e.parent; p != null; p = p.parent) {
    if (p.localName == 'table') return p;
  }
  return null;
}

/// Keeps only `<style>` in the head: fwfh shows a `<title>`.
void dropHeadContent(Document doc) {
  for (final e in doc.head?.children.toList() ?? <Element>[]) {
    if (e.localName != 'style') e.remove();
  }
}

final _percent = RegExp(r'^\s*\d+(\.\d+)?%\s*$');
final _cssWidthDecl = RegExp(r'(^|;)\s*width\s*:', caseSensitive: false);

/// [style] without the declarations matching [drop].
String _without(String style, RegExp drop) =>
    style.split(';').where((d) => !drop.hasMatch(d)).join(';');

/// The declarations that make a table a card: they move to a wrapping `<div>`.
final _box = RegExp(
  r'^\s*(border(?!-(collapse|spacing))|padding|background|margin|max-width)[\w-]*\s*:',
  caseSensitive: false,
);

/// A visible border, any padding or a radius (not `0`/`none`).
final _hasBox = RegExp(
  r'(^|;)\s*(border(-(top|right|bottom|left))?(-width)?|padding[\w-]*|border-radius)\s*:\s*(?!0(px)?\s*(;|$|!)|none)',
  caseSensitive: false,
);

/// fwfh 0.17.4 draws a table's border inside its padding and drops its radius. A full-width table
/// styled as a card gets its box on a `<div>` (laid out like a browser): the table keeps its width.
/// `max-width` and `margin` go with it, so the card is constrained and centred like the table was.
void _boxTables(Document doc) {
  for (final t in doc.querySelectorAll('table')) {
    final style = t.attributes['style'] ?? '';
    final width =
        RegExp(
          r'(?:^|;)\s*width\s*:\s*([^;]*)',
          caseSensitive: false,
        ).firstMatch(style)?[1] ??
        t.attributes['width'];
    if (!_hasBox.hasMatch(style) ||
        (width != null &&
            !RegExp(r'^\s*100(\.0+)?%\s*(!important)?\s*$').hasMatch(width))) {
      continue;
    }
    final decls = style.split(';');
    t.attributes['style'] = decls.where((d) => !_box.hasMatch(d)).join(';');
    final div = Element.tag('div')
      ..attributes['style'] = decls.where(_box.hasMatch).join(';');
    // A quote/signature marker goes with the card, or splitHtml would take the bare table.
    final marker = [...quoteSelectors, ...signatureSelectors].join(',');
    if (t.parent!.querySelectorAll(marker).contains(t)) {
      for (final a in ['class', 'id']) {
        final v = t.attributes.remove(a);
        if (v != null) div.attributes[a] = v;
      }
    }
    t.replaceWith(div);
    div.append(t);
  }
}

/// True when the effective `display` of [style] is `none`: comments are ignored, the last
/// declaration wins unless an earlier one is `!important` and the later one is not.
bool _hidden(String style) {
  String? value;
  var important = false;
  for (final d
      in style.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').split(';')) {
    final m = RegExp(
      r'^\s*display\s*:\s*(.*?)\s*(!\s*important)?\s*$',
      caseSensitive: false,
    ).firstMatch(d);
    if (m == null) continue;
    final imp = m[2] != null;
    if (important && !imp) continue;
    value = m[1]!.toLowerCase();
    important = imp;
  }
  return value == 'none';
}

/// Patches for what fwfh 0.17.4 ignores, before `_boxTables` moves a card's background.
// ponytail: all three go away with the litehtml renderer.
void _patchFwfh(Document doc) {
  for (final e in doc.querySelectorAll('*').toList()) {
    final style = e.attributes['style'] ?? '';
    // A hidden tracking pixel: customWidgetBuilder (postino_html_card.dart) bypasses display:none.
    if (e.localName == 'img' && _hidden(style)) {
      e.remove();
      continue;
    }
    // fwfh ignores `bgcolor`; put it first so an inline background still wins.
    // fwfh 0.17.4 applies no `<style>` rules (the element is display:none, no stylesheet is parsed),
    // so a stylesheet background can never be overridden here.
    final bg = e.attributes['bgcolor'];
    if (bg != null) e.attributes['style'] = 'background-color:$bg;$style';
    // fwfh ignores cell `height`, and `height:` in CSS is rigid: `min-height` is not.
    final h = e.attributes['height'];
    if ((e.localName == 'td' || e.localName == 'th') &&
        h != null &&
        _pixels.hasMatch(h)) {
      final px = _pixels.firstMatch(h)![1];
      e.attributes['style'] =
          '${e.attributes['style'] ?? ''};min-height:${px}px';
    }
  }
}

/// Strips whitespace and control characters, which browsers ignore in a scheme (`java\nscript:`).
bool _script(String url) => RegExp(
  r'^(javascript|vbscript):',
  caseSensitive: false,
).hasMatch(url.replaceAll(RegExp(r'[\x00-\x20]'), ''));

/// Cleans [html] and, unless [allowRemote], blocks every remote (http, https, `//`) resource:
/// `src`/`srcset`/`background`, CSS `url(...)` and `@import` in `style` attributes and `<style>`
/// (fonts too), `<link>`. `data:` stays; `cid:` and local schemes lose their `src` (a placeholder).
SafeHtml prepareHtml(String html, {required bool allowRemote}) {
  final doc = parse(html);
  _patchFwfh(doc);
  var blocked = false;
  double? width;

  String css(String s) {
    if (allowRemote) return s;
    return s
        .replaceAllMapped(_cssImport, (_) {
          blocked = true;
          return '';
        })
        .replaceAllMapped(_cssUrl, (m) {
          if (!_remote.hasMatch(m[2]!)) return m[0]!;
          blocked = true;
          return 'none';
        });
  }

  for (final e in doc.querySelectorAll('*')) {
    final tag = e.localName;
    if (_dropped.contains(tag)) {
      e.remove();
      continue;
    }
    if (tag == 'form') {
      e.replaceWith(DocumentFragment()..nodes.addAll(e.nodes.toList()));
      continue;
    }
    if (tag == 'link') {
      e.remove(); // dropped whatever the consent: not something «Mostra immagini» unlocks
      continue;
    }
    if (tag == 'style') {
      e.text = css(e.text);
      continue;
    }
    for (final key in e.attributes.keys.toList()) {
      final name = key.toString().toLowerCase();
      final value = e.attributes[key]!;
      if (name.startsWith('on') ||
          (_urlAttributes.contains(name) && _script(value))) {
        e.attributes.remove(key);
      } else if (name == 'style') {
        for (final m in _cssWidth.allMatches(value)) {
          width = _max(width, double.parse(m[1]!));
        }
        // fwfh 0.17.4 breaks tables: a cell width stays hard (css_sizing.dart:127, so «Status» breaks
        // mid-word) and a `width:100%` table splits columns evenly (html_table.dart:369-396).
        // Browsers treat the first as a minimum and size by content: so drop both, after the
        // measure above. Tables in px stay (scaled down by the card).
        // A one-column table keeps its percentage: fwfh has no columns to split, and without it
        // the table shrinks to its content.
        final cell = tag == 'td' || tag == 'th';
        final strip = cell || (tag == 'table' && _multiColumn(e));
        e.attributes[key] = css(
          strip ? _without(value, cell ? _cellWidth : _tablePercent) : value,
        );
      } else if (name == 'width') {
        // fwfh ignores the attribute on a table: a one-column one gets it as style.
        if (tag == 'table' &&
            _percent.hasMatch(value) &&
            !_multiColumn(e) &&
            !_cssWidthDecl.hasMatch(e.attributes['style'] ?? '')) {
          e.attributes['style'] =
              'width:${value.trim()};${e.attributes['style'] ?? ''}';
        }
        if (_pixels.firstMatch(value) case final m?) {
          width = _max(width, double.parse(m[1]!));
        }
      } else if (_resourceAttributes.contains(name)) {
        final kept = _keep(value, name == 'srcset', allowRemote);
        if (kept == null) {
          if (_anyRemote.hasMatch(value)) blocked = true;
          e.attributes.remove(key);
        }
      }
    }
  }
  _boxTables(doc);
  dropHeadContent(doc);
  return (html: doc.outerHtml, blocked: blocked, width: width);
}

double _max(double? a, double b) => a == null || b > a ? b : a;

/// [value] if it may load: `data:` always, remote only when [allowRemote]; anything else (`cid:`,
/// `file:`, relative) never. A `srcset` loads if every candidate may.
String? _keep(String value, bool srcset, bool allowRemote) {
  bool ok(String url) =>
      url.trimLeft().toLowerCase().startsWith('data:') ||
      (allowRemote && _remote.hasMatch(url));
  if (!srcset) return ok(value) ? value : null;
  // ponytail: a data: URL holding a comma splits wrongly here; such srcsets just stay blocked.
  return value.split(',').every(ok) ? value : null;
}
