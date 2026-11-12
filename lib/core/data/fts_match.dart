import '../domain/search_query.dart';

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// The FTS5 `MATCH` expression of [q], or null when it has nothing the index can look for (no letters or digits).
/// Free words, and those of the sender, recipients and subject, match as word beginnings (`fatt` finds «fattura»);
/// the phrase matches whole words, in order. Only letters and digits get through, each quoted: what the user types
/// is never FTS syntax, and the expression has no quote to escape.
String? ftsMatch(SearchQuery q) {
  List<String> words(String? s) => [for (final m in _word.allMatches(s ?? '')) m[0]!];
  String prefixes(Iterable<String> ws) => [for (final w in ws) '"$w"*'].join(' ');
  // The filter takes one phrase: it goes before each word.
  String column(String name, String? text) => [for (final w in words(text)) '{$name} : "$w"*'].join(' ');

  final phrase = words(q.phrase);
  final parts = [
    prefixes(q.terms.expand(words)),
    if (phrase.isNotEmpty) '"${phrase.join(' ')}"',
    column('sender', q.from),
    column('recipients', q.to),
    column('subject', q.subject),
  ].where((p) => p.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' ');
}
