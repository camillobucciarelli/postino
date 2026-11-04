/// What stands in for a removed secret.
const redacted = '[redatto]';

// ponytail: pattern list, not a parser; extend it when a new transport puts a secret in a message.
final _patterns = <(RegExp, String Function(Match))>[
  // Authorization headers, also inside a SASL string.
  (RegExp(r'\bBearer\s+[^\s",;]+', caseSensitive: false), (_) => 'Bearer $redacted'),
  // IMAP: the credentials follow the command.
  (RegExp(r'\bAUTHENTICATE\s+(\S+)\s+\S+', caseSensitive: false), (m) => 'AUTHENTICATE ${m[1]} $redacted'),
  (RegExp(r'\bLOGIN\s+("[^"]*"|\S+)\s+("[^"]*"|\S+)', caseSensitive: false), (_) => 'LOGIN $redacted'),
  // name: "value", name=value, "name":"value" (JSON, forms, query strings, toString of maps).
  (
    RegExp(
      r'''(["']?\b(?:access_token|refresh_token|id_token|client_secret|password|passwd|pwd|code|token|secret)\b["']?\s*[:=]\s*)("[^"]*"|'[^']*'|[^\s&,;}"']+)''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}$redacted',
  ),
  // Google tokens on their own: access (ya29.) and refresh (1//).
  (RegExp(r'\bya29\.[\w.-]+'), (_) => redacted),
  (RegExp(r'(?<![\w/])1//[\w-]+'), (_) => redacted),
];

/// [text] without the tokens and passwords it may carry; everything else as it is.
String redactSecrets(String text) {
  var out = text;
  for (final (pattern, replace) in _patterns) {
    out = out.replaceAllMapped(pattern, replace);
  }
  return out;
}
