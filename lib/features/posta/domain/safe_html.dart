import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

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
      if (_remote.hasMatch(e.attributes['href'] ?? '')) blocked = true;
      e.remove();
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
        e.attributes[key] = css(value);
        for (final m in _cssWidth.allMatches(value)) {
          width = _max(width, double.parse(m[1]!));
        }
      } else if (name == 'width') {
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
