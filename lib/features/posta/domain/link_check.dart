import 'displayed_hosts.dart';
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
