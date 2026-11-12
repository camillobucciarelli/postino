import 'search_query.dart';

enum _Field() {
  from,
  to,
  subject,
}

/// Gli operatori di testo della riga di ricerca, in italiano e in inglese; le maiuscole non contano.
const _fields = {
  'da': _Field.from,
  'from': _Field.from,
  'a': _Field.to,
  'to': _Field.to,
  'oggetto': _Field.subject,
  'subject': _Field.subject,
};

/// Gli operatori dei criteri: `è:`/`is:` (non letti, Stella), `ha:`/`has:` (allegati), `dopo:`/`after:` e
/// `prima:`/`before:` (giorni), `account:`.
const _criteria = {'è', 'is', 'ha', 'has', 'dopo', 'after', 'prima', 'before', 'account'};

// Un operatore col suo valore, una frase tra virgolette (anche non chiusa) o una parola.
final _token = RegExp(r'(?:(\p{L}+):)?(?:"([^"]*)"?|(\S+))', unicode: true);

final _day = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$');

/// Il giorno locale di [s] (`2026-03-01` o `2026/03/01`); null se non è una data che esiste.
DateTime? _parseDay(String s) {
  final m = _day.firstMatch(s);
  if (m == null) return null;
  final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final day = DateTime(y, mo, d);
  return day.year == y && day.month == mo && day.day == d ? day : null;
}

/// Legge la riga scritta dall'utente: parole in AND, `"frase esatta"`, `da:`, `a:`, `oggetto:` (e `from:`, `to:`,
/// `subject:`) e i criteri `è:nonletto`, `è:stella`, `ha:allegato`, `dopo:AAAA-MM-GG`, `prima:AAAA-MM-GG`,
/// `account:nome` (e `is:unread`, `is:starred`, `has:attachment`, `after:`, `before:`). Un operatore senza ancora il
/// valore (mentre si scrive `da:`) non conta; un `nome:` che non è un operatore, o un operatore col valore che non
/// capisce (`dopo:ieri`, `è:rosso`), resta testo libero. Una riga vuota o di soli spazi dà una ricerca vuota.
// ponytail: una seconda frase tra virgolette diventa parole libere; la ricerca ha una sola frase (come la spec).
SearchQuery parseSearchQuery(String input) {
  final terms = <String>[];
  String? phrase;
  final fields = {for (final f in _Field.values) f: <String>[]};
  final accountNames = <String>[];
  bool? unread;
  bool? starred;
  bool? hasAttachment;
  DateTime? after;
  DateTime? before;

  // Applies the criterion [name]:[value]; false when the value is not one it knows.
  bool criterion(String name, String value) {
    final v = value.toLowerCase();
    switch (name) {
      case 'è' || 'is' when const {'nonletto', 'unread'}.contains(v):
        unread = true;
      case 'è' || 'is' when const {'stella', 'starred'}.contains(v):
        starred = true;
      case 'ha' || 'has' when const {'allegato', 'allegati', 'attachment', 'attachments'}.contains(v):
        hasAttachment = true;
      case 'dopo' || 'after' when _parseDay(value) != null:
        after = _parseDay(value);
      case 'prima' || 'before' when _parseDay(value) != null:
        before = _parseDay(value);
      case 'account':
        accountNames.add(value);
      default:
        return false;
    }
    return true;
  }

  for (final m in _token.allMatches(input)) {
    final name = m[1]?.toLowerCase();
    final quoted = m[2];
    final bare = m[3];
    final value = (quoted ?? bare ?? '').trim();
    final free = name == null ? value : '$name:${quoted ?? bare ?? ''}';
    final typing = name == null && bare != null && bare.endsWith(':')
        ? bare.substring(0, bare.length - 1).toLowerCase()
        : null;
    if (_fields[name] case final field?) {
      if (value.isNotEmpty) fields[field]!.add(value);
    } else if (_criteria.contains(name)) {
      if (value.isNotEmpty && !criterion(name!, value)) terms.add(free);
    } else if (name == null && quoted != null) {
      if (value.isEmpty) continue;
      if (phrase == null) {
        phrase = value;
      } else {
        terms.addAll(value.split(RegExp(r'\s+')));
      }
    } else if (_fields.containsKey(typing) || _criteria.contains(typing)) {
      // L'operatore appena digitato, senza valore.
      continue;
    } else {
      // Un `nome:` sconosciuto: il testo com'è.
      terms.add(free);
    }
  }
  String? join(_Field f) => fields[f]!.isEmpty ? null : fields[f]!.join(' ');
  return SearchQuery(
    terms: terms,
    phrase: phrase,
    from: join(_Field.from),
    to: join(_Field.to),
    subject: join(_Field.subject),
    after: after,
    before: before,
    unread: unread,
    starred: starred,
    hasAttachment: hasAttachment,
    accountNames: accountNames,
  );
}
