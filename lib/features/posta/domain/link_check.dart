import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parse;

import 'punycode.dart';

/// Why a link needs a Dialog before it opens: the `domain` it really goes to (decoded), whether it is `punycode`, and whether its text could not be found (`unverified`).
typedef LinkWarning = ({String domain, bool punycode, bool unverified});

/// Second-level labels under which a two-letter country code is still the public suffix (co.uk).
// ponytail: no public-suffix list; hosting suffixes like `github.io` are not special-cased. Add a list if a case matters.
const _secondLevel = {'co', 'com', 'org', 'net', 'gov', 'edu', 'ac', 'or', 'ne', 'go'};

final _address = RegExp(r'^[\d.]+$|:');

/// The registrable domain of [host]: one label plus the public suffix (mail.paypal.co.uk is paypal.co.uk).
/// An IP address is its own domain.
String registrableDomain(String host) {
  final labels = host.toLowerCase().split('.');
  if (labels.length <= 2 || _address.hasMatch(host)) return host.toLowerCase();
  final keep = labels.last.length == 2 && _secondLevel.contains(labels[labels.length - 2]) ? 3 : 2;
  return labels.skip(labels.length - keep).join('.');
}

final _url = RegExp('^(?:https?://)?([^\\s/?#:]+)', caseSensitive: false);
final _scheme = RegExp('^https?://', caseSensitive: false);
final _domain = RegExp(r'^[^\s.]+(\.[^\s.]+)*\.[^\s.\d]{2,}$');

final _edges = RegExp(
  r'^[\s.,;:!?()\[\]<>"\u2018\u2019\u201c\u201d\u2013\u2014-]+|[\s.,;:!?()\[\]<>"\u2018\u2019\u201c\u201d\u2013\u2014-]+$',
);

/// The hosts a link's visible [text] claims to go to: every token that is a URL (`https://…`, `www.…`), or the
/// whole text when it is a bare domain; trailing punctuation is ignored.
// ponytail: a bare domain inside a sentence ("Accedi su paypal.com") is not seen: "report.pdf" looks the same.
List<String> displayedHosts(String text) {
  final trimmed = text.trim();
  final hosts = <String>[];
  for (final raw in trimmed.split(RegExp(r'\s+'))) {
    final token = raw.replaceAll(_edges, '');
    if (!_scheme.hasMatch(token) && !token.toLowerCase().startsWith('www.') && raw != trimmed) continue;
    final host = _url.firstMatch(token)?[1]?.toLowerCase().split('@').last.replaceAll(RegExp(r'\.+$'), '');
    if (host != null && _domain.hasMatch(host)) hosts.add(host);
  }
  return hosts;
}

/// A warning if [target] (http or https) goes to another registrable domain than one [text] shows;
/// null otherwise, and for `mailto:` or a text with no domain. Subdomains of the same site are fine.
LinkWarning? deceptiveLink(Uri target, String text) {
  if (target.scheme != 'http' && target.scheme != 'https' || target.host.isEmpty) return null;
  final real = decodeHost(target.host.toLowerCase().replaceAll(RegExp(r'\.+$'), ''));
  final mismatch = displayedHosts(text).any((h) => registrableDomain(real) != registrableDomain(decodeHost(h)));
  return mismatch ? (domain: real, punycode: hasPunycode(target.host), unverified: false) : null;
}

/// What to warn about before opening [target], given the [texts] of the links that go to it. Fails closed: an
/// http(s) URL no link text could be found for (a rewritten href, a WebView redirect) warns as `unverified`.
LinkWarning? linkWarning(Uri target, Iterable<String> texts) {
  if (target.scheme != 'http' && target.scheme != 'https') return null;
  if (texts.isEmpty || texts.contains(unverifiableText)) {
    final real = decodeHost(target.host.toLowerCase().replaceAll(RegExp(r'\.+$'), ''));
    return (domain: real, punycode: hasPunycode(target.host), unverified: true);
  }
  return texts.map((t) => deceptiveLink(target, t)).nonNulls.firstOrNull;
}

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

/// Elements whose content is not shown as plain label text.
const _unseen = {
  'details',
  'template',
  'noscript',
  'select',
  'datalist',
  'audio',
  'video',
  'object',
  'iframe',
  'canvas',
  'dialog',
  'script',
  'title',
  'rp',
  'noembed',
  'noframes',
  'xmp',
  'area',
  'optgroup',
  'svg',
  'math',
  'bdo',
  'bdi',
};

/// The visible texts of the links of [html], by `href`: what a tap on that URL claims to open. CSS cannot be judged
/// here, so a link whose label could be altered fails closed ([unverifiableText], hence a Dialog): the document has a
/// `<style>` or a stylesheet `<link>`; the link or an ancestor has a `style`; an empty label (a `::before` could fill
/// it); or a descendant could hide text (`style`, `hidden`, `aria-hidden`, or one of [_unseen]).
/// A document with none of these keeps the label, plain nested tags (`<b>`) included.
Map<String, List<String>> linkTexts(String html) {
  final doc = parse(html);
  final styled = doc.querySelector('style, link[rel~=stylesheet]') != null;
  final out = <String, List<String>>{};
  for (final a in doc.querySelectorAll('a[href]')) {
    var inlineStyle = false;
    for (Element? e = a; e != null; e = e.parent) {
      inlineStyle |= e.attributes.containsKey('style') || e.attributes.containsKey('dir');
    }
    final hideable =
        styled ||
        inlineStyle ||
        a.text.trim().isEmpty ||
        a
            .querySelectorAll('*')
            .any(
              (e) =>
                  _unseen.contains(e.localName) ||
                  e.attributes.keys.any((k) => const {'style', 'hidden', 'aria-hidden', 'dir'}.contains(k)),
            );
    (out[a.attributes['href']!] ??= []).add(hideable ? unverifiableText : a.text);
  }
  return out;
}
