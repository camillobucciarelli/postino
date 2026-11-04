/// What stands in for a removed secret.
const redacted = '[redatto]';

/// A quoted value, escaped quotes included: a secret never leaks past an escaped `"`.
const _quoted =
    r'"(?:[^"\\]|\\.)*"'
    '|'
    r"'(?:[^'\\]|\\.)*'";

// ponytail: pattern list, not a parser; extend it when a new transport puts a secret in a message.
final _patterns = <(RegExp, String Function(Match))>[
  // Authorization headers, also inside a SASL string.
  (RegExp(r'\bBearer\s+[^\s",;]+', caseSensitive: false), (_) => 'Bearer $redacted'),
  // IMAP commands, upper case as RFC 3501 writes them (so «Login to mario@…» keeps its address): the credentials
  // follow the command.
  (RegExp(r'\bAUTHENTICATE\s+(\S+)\s+\S+'), (m) => 'AUTHENTICATE ${m[1]} $redacted'),
  (RegExp('\\bLOGIN\\s+(?:$_quoted|\\S+)\\s+(?:$_quoted|\\S+)'), (_) => 'LOGIN $redacted'),
  // name: "value", name=value, "name":"value" (JSON, forms, query strings, toString of maps). Unquoted, the value
  // runs to the next delimiter, spaces included: a password may have them.
  (
    RegExp(
      '(["\']?\\b(?:access_token|refresh_token|id_token|client_secret|password|passwd|pwd|token|secret)\\b["\']?'
      '\\s*[:=]\\s*)($_quoted|[^\\s,;&}"\'][^,;&}\\n]*)',
      caseSensitive: false,
    ),
    (m) => '${m[1]}$redacted',
  ),
  // The OAuth authorization code only as a parameter: «status code: 401» stays.
  (RegExp(r'\bcode=[^\s&]+'), (_) => 'code=$redacted'),
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
