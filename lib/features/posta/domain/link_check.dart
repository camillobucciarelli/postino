import 'link_label.dart' show unverifiableText;
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

/// Where two addresses can run together in a label (`www.a.com,www.b.com`): split there, never read as one host.
final _separators = RegExp('[,;|<>"\'()“”‘’]+');
final _hostname = RegExp(r'^[\p{L}\p{N}.-]+$', unicode: true);

/// Stands for a shown address that is not a plain hostname: it matches no real host, so the link warns.
const _malformed = '\u0000malformed';

/// The hosts a link's visible [text] claims to go to: every token that is an explicit URL (`https://…`, `www.…`);
/// bare domains too when the whole text is one, or when there are several (`a.com;b.com`). Tokens are split at
/// separators (comma, semicolon, pipe, quotes, parentheses), so two addresses never read as one hostname; an explicit
/// URL whose host is not a plain hostname counts as [_malformed] (warns). Trailing punctuation is ignored: `paypal.com,`
/// and `www.paypal.com.` show `paypal.com`.
// ponytail: a bare domain inside a sentence ("Accedi su paypal.com") is not seen: "report.pdf" looks the same.
List<String> displayedHosts(String text) {
  final hosts = <String>[];
  final tokens = <String>[];
  for (final raw in text.trim().split(RegExp(r'\s+'))) {
    // An IP literal in an explicit URL is a host as it is; a bare `1.2.3` is a version, not a host.
    var rest = raw;
    if (_literal.firstMatch(raw) case final m? when m[1] != null) {
      hosts.add(m[1]!.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), ''));
      rest = raw.substring(m.end);
    }
    tokens.addAll(rest.split(_separators).map((t) => t.replaceAll(_edges, '')).where((t) => t.isNotEmpty));
  }
  final bare = <String>[];
  for (final token in tokens) {
    final explicit = _scheme.hasMatch(token) || token.toLowerCase().startsWith('www.');
    final host = _url.firstMatch(token)?[1]?.toLowerCase().split('@').last.replaceAll(RegExp(r'\.+$'), '');
    if (host == null || !_domain.hasMatch(host)) {
      if (explicit) hosts.add(_malformed);
      continue;
    }
    if (!_hostname.hasMatch(host)) {
      if (explicit) hosts.add(_malformed);
    } else {
      (explicit ? hosts : bare).add(host);
    }
  }
  if ((tokens.length == 1 && hosts.isEmpty) || hosts.isNotEmpty || bare.length >= 2) hosts.addAll(bare);
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
