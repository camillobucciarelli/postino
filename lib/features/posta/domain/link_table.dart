import 'dart:math';

import 'package:html/parser.dart' show parse;

import 'link_label.dart';

/// Where a link really goes (`href`, as the sender wrote it) and what it shows (`label`, or [unverifiableText]).
typedef LinkEntry = ({String href, String label});

const _host = 'postino.invalid';

/// A random value for one rendering, so a sender cannot write a token of its own.
String newLinkNonce() {
  final random = Random.secure();
  return [for (var i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

/// An HTML body whose every link was replaced by an opaque token, and the table behind the tokens. A tap reports the
/// token, which no WebView or renderer can respell, so what is looked up is exactly what the sender wrote and the
/// label of that very link: no URL is ever compared (ports, IDN, case, encodings are irrelevant).
class LinkTable(final String html, final List<LinkEntry> _entries, final String _nonce) {
  /// The entry of the token [url], null for any other URL (not a link of this body: a redirect, a crafted one).
  LinkEntry? lookup(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host != _host) return null;
    final s = u.pathSegments;
    if (s.length != 3 || s[0] != 'l' || s[1] != _nonce) return null;
    final i = int.tryParse(s[2]);
    return i == null || i < 0 || i >= _entries.length ? null : _entries[i];
  }
}

/// [html] with every `<a href>` and `<area href>` replaced by `https://postino.invalid/l/<nonce>/<N>`. Any href the
/// sender wrote, even to that host, is replaced too, so only tokens made here exist.
LinkTable tokenizeLinks(String html, {required String nonce}) {
  final doc = parse(html);
  final styled = doc.querySelector('style, link[rel~=stylesheet]') != null;
  final entries = <LinkEntry>[];
  for (final a in doc.querySelectorAll('a[href], area[href]')) {
    // An in-page jump leaves the document nowhere: nothing to vouch for, so it stays as written.
    if (a.attributes['href']!.trimLeft().startsWith('#')) continue;
    entries.add((href: a.attributes['href']!, label: linkLabel(a, styled: styled)));
    a.attributes['href'] = 'https://$_host/l/$nonce/${entries.length - 1}';
  }
  return LinkTable(doc.outerHtml, entries, nonce);
}
