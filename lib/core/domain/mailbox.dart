import 'dart:convert';

/// One address of a `From`, `To` or `Cc` header: the display [name], if any, and the [address].
typedef Mailbox = ({String? name, String address});

/// `Ada Okafor <ada@example.com>`, or the bare address without a name: how To and Cc entries are kept.
String formatMailbox(Mailbox m) =>
    m.name == null ? m.address : '${m.name} <${m.address}>';

/// One mailbox: `Name <address>`, `"Quoted, Name" <address>`, `<address>` or a bare address,
/// with RFC 2047 encoded words decoded in the name.
Mailbox parseMailbox(String s) {
  final angle = RegExp(r'^(.*?)<([^<>]*)>\s*$', dotAll: true).firstMatch(s);
  if (angle == null) return (name: null, address: s.trim());
  var name = angle[1]!.trim();
  if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
    name = name
        .substring(1, name.length - 1)
        .replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
  }
  name = decodeWords(name).trim();
  return (name: name.isEmpty ? null : name, address: angle[2]!.trim());
}

/// An address list header: commas inside quotes or `<...>` do not split it.
List<Mailbox> parseMailboxes(String header) {
  final parts = <String>[];
  final current = StringBuffer();
  var quoted = false, angle = false, escaped = false;
  for (final ch in header.split('')) {
    if (escaped) {
      escaped = false;
    } else if (ch == r'\' && quoted) {
      escaped = true;
    } else if (ch == '"') {
      quoted = !quoted;
    } else if (!quoted && ch == '<') {
      angle = true;
    } else if (!quoted && ch == '>') {
      angle = false;
    } else if (ch == ',' && !quoted && !angle) {
      parts.add('$current');
      current.clear();
      continue;
    }
    current.write(ch);
  }
  parts.add('$current');
  return [
    for (final p in parts)
      if (p.trim().isNotEmpty) parseMailbox(p),
  ];
}

final _word = RegExp(r'=\?([^?\s]+)\?([BbQq])\?([^?\s]*)\?=');

/// RFC 2047 encoded words (`=?UTF-8?B?...?=`, `=?ISO-8859-1?Q?...?=`) decoded; the blanks between two
/// of them go. UTF-8, Latin-1 and ASCII; another charset is read as UTF-8.
// ponytail: windows-1252 read as Latin-1 (differs only in 0x80–0x9F); a charset table if mojibake shows up.
String decodeWords(String s) => s
    .replaceAllMapped(RegExp(r'(\?=)\s+(?==\?)'), (m) => m[1]!)
    .replaceAllMapped(_word, (m) {
      final List<int> bytes;
      try {
        bytes = m[2]!.toUpperCase() == 'B'
            ? base64.decode(base64.normalize(m[3]!))
            : _quoted(m[3]!);
      } on FormatException {
        return m[0]!;
      }
      final charset = m[1]!.toLowerCase().split('*').first;
      return switch (charset) {
        'iso-8859-1' ||
        'latin1' ||
        'windows-1252' ||
        'us-ascii' => latin1.decode(bytes),
        _ => utf8.decode(bytes, allowMalformed: true),
      };
    });

List<int> _quoted(String s) {
  final out = <int>[];
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '_') {
      out.add(0x20);
    } else if (c == '=' && i + 2 < s.length) {
      out.add(int.parse(s.substring(i + 1, i + 3), radix: 16));
      i += 2;
    } else {
      out.addAll(utf8.encode(c));
    }
  }
  return out;
}
