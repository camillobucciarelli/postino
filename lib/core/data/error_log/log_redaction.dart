/// What stands in for a removed secret.
const redacted = '[redatto]';

/// A quoted value with its escapes; the closing quote is optional, so a value cut short (a FormatException shows
/// only part of its source) goes to the end.
const _double = r'"(?:[^"\\]|\\.)*"?';
const _single = r"'(?:[^'\\]|\\.)*'?";

/// A value quoted with escaped quotes, i.e. JSON inside a JSON string: an escaped quote may also be part of the
/// value, so it runs to the end of the enclosing string (its first unescaped quote), which stays.
const _escaped = r'\\+"(?:[^"\\]|\\.)*';

/// Unquoted, a value runs to the next delimiter, spaces included: a password may have them. `&`, `;` and a line end
/// always close it; a comma, brace, bracket, parenthesis or quote only when what follows ends the value too, so
/// `password=a,b` goes whole and `"password=a", x` keeps its quote.
const _unquoted = r'''[^\s,;&}"'](?:[^,;&}\n"')\]]|[,}"')\]](?![\s,;&})\]"']|$))*''';

/// Names whose value is a secret. `authorization` takes the whole header value, scheme included.
const _secretNames = 'access_token|refresh_token|id_token|client_secret|authorization|password|passwd|pwd|token|secret';

/// An IMAP argument: quoted, a literal (`{n}` then the line), or an atom (no quotes nor backslashes).
const _imapArgument = '$_double|\\{\\d+\\+?\\}\\r?\\n[^\\r\\n]*|[^\\s"\'\\\\]+';

// ponytail: pattern list, not a parser; extend it when a new transport puts a secret in a message.
// Order matters: whole secret fields first, so a pattern for bare tokens never cuts into a quoted value and opens
// its quotes; each pattern then keeps the quotes around what it removes.
final _patterns = <(RegExp, String Function(Match))>[
  // name: "value", name='value', name=value, "name":"value", \"name\":\"value\" (JSON, forms, query strings, maps).
  (
    RegExp(
      '((?:\\\\*["\'])?\\b(?:$_secretNames)\\b(?:\\\\*["\'])?\\s*[:=]\\s*)'
      '(?:($_escaped)|($_double)|($_single)|$_unquoted)',
      caseSensitive: false,
    ),
    (m) => switch ((m[2], m[3], m[4])) {
      (final escaped?, _, _) => '${m[1]}${_opening(escaped)}$redacted${_opening(escaped)}',
      (final quoted?, _, _) || (_, final quoted?, _) || (_, _, final quoted?) => '${m[1]}${_requote(quoted)}',
      _ => '${m[1]}$redacted',
    },
  ),
  // IMAP commands, upper case as RFC 3501 writes them (so «Login to mario@…» keeps its address).
  (RegExp('\\bLOGIN\\s+(?:$_imapArgument)\\s+(?:$_imapArgument)'), (_) => 'LOGIN $redacted'),
  (RegExp(r'\bAUTHENTICATE\s+(\S+)\s+[^\s"\\]+'), (m) => 'AUTHENTICATE ${m[1]} $redacted'),
  // Bare tokens, anywhere else. Tokens have no quotes, backslashes or spaces: none is consumed.
  (RegExp(r'''\bBearer\s+[^\s"',;\\]+''', caseSensitive: false), (_) => 'Bearer $redacted'),
  // The OAuth authorization code only as a parameter: «status code: 401» stays.
  (RegExp(r'''\bcode=[^\s&"'\\]+'''), (_) => 'code=$redacted'),
  // Google tokens on their own: access (ya29.) and refresh (1//).
  (RegExp(r'\bya29\.[\w.-]+'), (_) => redacted),
  (RegExp(r'(?<![\w/])1//[\w-]+'), (_) => redacted),
];

/// The backslashes and quote that open an escaped value.
String _opening(String value) => value.substring(0, value.indexOf('"') + 1);

/// [quoted] replaced, keeping its opening quote and its closing one if it had it.
String _requote(String quoted) {
  final q = quoted[0];
  final closed = quoted.length > 1 && quoted.endsWith(q) && !_escapedAtEnd(quoted);
  return '$q$redacted${closed ? q : ''}';
}

/// Whether the last character of [s] is escaped by an odd run of backslashes before it.
bool _escapedAtEnd(String s) {
  var n = 0;
  for (var i = s.length - 2; i >= 0 && s[i] == r'\'; i--) {
    n++;
  }
  return n.isOdd;
}

/// [text] without the tokens and passwords it may carry; everything else as it is.
String redactSecrets(String text) {
  var out = text;
  for (final (pattern, replace) in _patterns) {
    out = out.replaceAllMapped(pattern, replace);
  }
  return out;
}
