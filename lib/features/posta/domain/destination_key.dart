import 'dart:convert';

import 'punycode.dart';

final _parts = RegExp(r'^([a-z][a-z0-9+.-]*):(?://([^/?#]*))?([^?#]*)(\?[^#]*)?', caseSensitive: false);
final _port = RegExp(r':(\d*)$');

/// One key for every spelling of a destination, so the `href` a sender wrote and the URL a WebView reports collide
/// (a collision only adds link texts to check, never hides one). Covered: scheme and host case, trailing dot on the
/// host, Unicode and `xn--` hosts (both end up Unicode), default ports (`:80`, `:443`, empty), userinfo, backslashes
/// read as slashes, tabs and newlines inside the URL, an empty path as `/`, percent-encoding (case and
/// encoded/decoded characters), the fragment. Null when the URL cannot be read at all: the caller fails closed.
String? destinationKey(String url) {
  final cleaned = url.replaceAll(RegExp(r'[\t\n\r]'), '').trim().replaceAll(r'\', '/');
  final m = _parts.firstMatch(cleaned);
  if (m == null) return null;
  final scheme = m[1]!.toLowerCase();
  final authority = m[2];
  if (authority == null) return '$scheme:${_decode(m[3]!)}';
  var host = authority.substring(authority.lastIndexOf('@') + 1);
  var port = '';
  if (_port.firstMatch(host) case final p? when !host.endsWith(']')) {
    port = p[1]!;
    host = host.substring(0, p.start);
  }
  final canonical = _host(host);
  if (canonical == null) return null;
  host = canonical;
  final defaultPort = switch (scheme) {
    'http' => '80',
    'https' => '443',
    _ => '',
  };
  final path = _dotSegments(_decode(m[3]!));
  return '$scheme://$host${port.isEmpty || port == defaultPort ? '' : ':$port'}${path.isEmpty ? '/' : path}${_decode(m[4] ?? '')}';
}

/// Characters a browser maps to something else in a host (full-width forms, `ß`, joiners, ideographic dots): not
/// reproduced here, so such a host has no key and the caller fails closed.
final _mapped = RegExp('[\u00DF\u03C2\u00AD\u200B-\u200D\u2060\uFF00-\uFFEF\u3002]');

/// [host] as a browser reports it: percent-decoded, lowercase, no trailing dot, Unicode form of `xn--` labels, IPv4 in
/// any base as dotted decimal, IPv6 uncompressed. Null when it cannot be told reliably.
String? _host(String host) {
  if (host.startsWith('[')) {
    if (!host.endsWith(']')) return null;
    try {
      final groups = Uri.parseIPv6Address(host.substring(1, host.length - 1).toLowerCase());
      return '[${[for (var i = 0; i < 16; i += 2) ((groups[i] << 8) | groups[i + 1]).toRadixString(16)].join(':')}]';
    } on FormatException {
      return null;
    }
  }
  final h = _decode(host);
  if (h.contains(_mapped) || h.contains('%') || h.contains(' ')) return null;
  final labels = h.toLowerCase().replaceAll(RegExp(r'\.+$'), '').split('.');
  if (labels.last.isEmpty && labels.length == 1) return null;
  if (RegExp(r'^(0x[0-9a-f]*|\d+)$').hasMatch(labels.last)) return _ipv4(labels);
  return decodeHost(labels.join('.'));
}

/// WHATWG IPv4 parsing: 1 to 4 numbers in decimal, octal (`0177`) or hex (`0x7f`); the last fills the rest.
String? _ipv4(List<String> labels) {
  if (labels.length > 4) return null;
  final n = <int>[];
  for (final l in labels) {
    final v = l.startsWith('0x')
        ? (l.length == 2 ? 0 : int.tryParse(l.substring(2), radix: 16))
        : l.length > 1 && l.startsWith('0')
        ? int.tryParse(l.substring(1), radix: 8)
        : int.tryParse(l);
    if (v == null) return null;
    n.add(v);
  }
  for (final v in n.take(n.length - 1)) {
    if (v > 255) return null;
  }
  if (n.last >= 1 << (8 * (5 - n.length))) return null;
  var ip = n.last;
  for (var i = 0; i < n.length - 1; i++) {
    ip += n[i] << (8 * (3 - i));
  }
  return [for (var i = 3; i >= 0; i--) (ip >> (8 * i)) & 255].join('.');
}

/// [path] without `.` and `..` segments, as a browser resolves it.
String _dotSegments(String path) {
  if (!path.contains('.')) return path;
  final out = <String>[];
  final segments = path.split('/');
  for (final (i, seg) in segments.indexed) {
    if (seg == '..') {
      if (out.length > 1) out.removeLast();
      if (i == segments.length - 1) out.add('');
    } else if (seg == '.') {
      if (i == segments.length - 1) out.add('');
    } else {
      out.add(seg);
    }
  }
  return out.join('/');
}

/// An absolute http(s) [href] that [destinationKey] cannot read: it may be any destination.
bool opaqueDestination(String href) =>
    RegExp(r'^\s*https?:', caseSensitive: false).hasMatch(href) && destinationKey(href) == null;

/// [s] with its percent-encoded UTF-8 decoded; a sequence that is not valid UTF-8 stays, in upper case.
String _decode(String s) => s.replaceAllMapped(RegExp('(?:%[0-9a-fA-F]{2})+'), (m) {
  final bytes = [for (var i = 0; i < m[0]!.length; i += 3) int.parse(m[0]!.substring(i + 1, i + 3), radix: 16)];
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return m[0]!.toUpperCase();
  }
});
