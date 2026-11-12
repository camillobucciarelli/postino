import 'search_query.dart';

enum _Field() {
  from,
  to,
  subject,
}

/// Gli operatori della riga di ricerca, in italiano e in inglese; le maiuscole non contano.
const _operators = {
  'da': _Field.from,
  'from': _Field.from,
  'a': _Field.to,
  'to': _Field.to,
  'oggetto': _Field.subject,
  'subject': _Field.subject,
};

// Un operatore col suo valore, una frase tra virgolette (anche non chiusa) o una parola.
final _token = RegExp(r'(?:(\p{L}+):)?(?:"([^"]*)"?|(\S+))', unicode: true);

/// Legge la riga scritta dall'utente: parole in AND, `"frase esatta"`, `da:`, `a:`, `oggetto:` (e `from:`, `to:`,
/// `subject:`). Un operatore senza ancora il valore (mentre si scrive `da:`) non conta, e un `nome:` che non è un
/// operatore resta testo libero. Una riga vuota o di soli spazi dà una ricerca vuota.
// ponytail: una seconda frase tra virgolette diventa parole libere; la ricerca ha una sola frase (come la spec).
SearchQuery parseSearchQuery(String input) {
  final terms = <String>[];
  String? phrase;
  final fields = {for (final f in _Field.values) f: <String>[]};
  for (final m in _token.allMatches(input)) {
    final name = m[1]?.toLowerCase();
    final quoted = m[2];
    final bare = m[3];
    final value = (quoted ?? bare ?? '').trim();
    if (_operators[name] case final field?) {
      if (value.isNotEmpty) fields[field]!.add(value);
    } else if (name == null && quoted != null) {
      if (value.isEmpty) continue;
      if (phrase == null) {
        phrase = value;
      } else {
        terms.addAll(value.split(RegExp(r'\s+')));
      }
    } else if (name == null &&
        bare!.endsWith(':') &&
        _operators.containsKey(bare.substring(0, bare.length - 1).toLowerCase())) {
      // L'operatore appena digitato, senza valore.
      continue;
    } else {
      // Un `nome:` sconosciuto: il testo com'è.
      terms.add(name == null ? value : '$name:${quoted ?? bare ?? ''}');
    }
  }
  String? join(_Field f) => fields[f]!.isEmpty ? null : fields[f]!.join(' ');
  return SearchQuery(
    terms: terms,
    phrase: phrase,
    from: join(_Field.from),
    to: join(_Field.to),
    subject: join(_Field.subject),
  );
}
