/// What stands in for a removed secret.
const redacted = '[redatto]';

/// Quoted values, escapes included, so a secret never leaks past an escaped quote: "…", '…', and \"…\" (JSON
/// inside a JSON string).
const _double = r'"(?:[^"\\]|\\.)*"';
const _single = r"'(?:[^'\\]|\\.)*'";
const _escaped = r'\\"(?:[^"\\]|\\[^"])*\\"';

/// Names whose value is a secret. `authorization` takes the whole header value, scheme included.
const _secretNames = 'access_token|refresh_token|id_token|client_secret|authorization|password|passwd|pwd|token|secret';

/// Unquoted, a value runs to the next delimiter, spaces included: a password may have them.
const _unquoted = r'''[^\s,;&}"'\\][^,;&}\n]*''';

// ponytail: pattern list, not a parser; extend it when a new transport puts a secret in a message.
// Order matters: whole secret fields first, so a pattern for bare tokens never cuts into a quoted value and opens
// its quotes; each pattern then keeps the quotes around what it removes.
final _patterns = <(RegExp, String Function(Match))>[
  // name: "value", name='value', name=value, "name":"value", \"name\":\"value\" (JSON, forms, query strings, maps).
  (
    RegExp(
      '((?:\\\\?["\'])?\\b(?:$_secretNames)\\b(?:\\\\?["\'])?\\s*[:=]\\s*)'
      '(?:($_escaped)|($_double)|($_single)|$_unquoted)',
      caseSensitive: false,
    ),
    (m) => switch ((m[2], m[3], m[4])) {
      (_?, _, _) => '${m[1]}\\"$redacted\\"',
      (_, _?, _) => '${m[1]}"$redacted"',
      (_, _, _?) => "${m[1]}'$redacted'",
      _ => '${m[1]}$redacted',
    },
  ),
  // IMAP commands, upper case as RFC 3501 writes them (so «Login to mario@…» keeps its address).
  (RegExp('\\bLOGIN\\s+(?:$_double|\\S+)\\s+(?:$_double|\\S+)'), (_) => 'LOGIN $redacted'),
  (RegExp(r'\bAUTHENTICATE\s+(\S+)\s+[^\s"\\]+'), (m) => 'AUTHENTICATE ${m[1]} $redacted'),
  // Bare tokens, anywhere else. Tokens have no quotes, backslashes or spaces: none is consumed.
  (RegExp(r'''\bBearer\s+[^\s"',;\\]+''', caseSensitive: false), (_) => 'Bearer $redacted'),
  // The OAuth authorization code only as a parameter: «status code: 401» stays.
  (RegExp(r'''\bcode=[^\s&"'\\]+'''), (_) => 'code=$redacted'),
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
