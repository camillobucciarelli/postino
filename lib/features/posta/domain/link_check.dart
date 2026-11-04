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
final _literal = RegExp(
  r'^\W*https?://(\[[0-9a-f:.]+\]|\d{1,3}(?:\.\d{1,3}){3})(?=[/?#:\s)>\"\u201d,;!?]|\.?(?:\s|$))',
  caseSensitive: false,
);
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
    // An IP literal in an explicit URL is a host as it is; a bare `1.2.3` is a version, not a host.
    if (_literal.firstMatch(raw)?[1] case final ip?) {
      hosts.add(ip.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), ''));
      continue;
    }
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
