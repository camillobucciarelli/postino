import 'dart:convert' show utf8;

import '../../domain/search_query.dart';
import 'imap_folder_sync.dart' show imapDate;

/// The `UID SEARCH` criteria for [query] (#208, `docs/research/ricerca-server-per-provider.md`), `CHARSET UTF-8`
/// first; null when there is nothing to look for. With [below] only the UIDs lower than it: the next page of a
/// folder. The user's text never reaches the command raw: each word is a quoted string with `\` and `"` escaped, or,
/// when it has more than printable ASCII, a literal (`{n}` and its bytes), so it can never close the string or add a
/// key. Words are searched as `TEXT` (header and body, a substring on most servers), the words of sender,
/// recipients and subject each on their own, as the local search reads them. Days are those of the Date header, the
/// date the list shows (`SENTSINCE`; INTERNALDATE is the arrival; SEARCH has no time); attachments are the
/// `multipart/mixed` guess the sync makes from the headers (#206).
// ponytail: per-message criteria; one SEARCH per criterion and an intersection if QA misses threads.
String? imapSearchCriteria(SearchQuery query, {int? below}) {
  String clean(String s) => s.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
  List<String> words(String? s) => [
    for (final w in clean(s ?? '').split(RegExp(r'\s+')))
      if (w.isNotEmpty) w,
  ];
  final phrase = words(query.phrase).join(' ');
  String day(DateTime d) => imapDate(DateTime(d.year, d.month, d.day));
  final keys = [
    for (final t in query.terms)
      for (final w in words(t)) 'TEXT ${_argument(w)}',
    if (phrase.isNotEmpty) 'TEXT ${_argument(phrase)}',
    for (final w in words(query.from)) _any(['FROM', 'HEADER From'], w),
    for (final w in words(query.to)) _any(['TO', 'CC', 'HEADER To', 'HEADER Cc'], w),
    for (final w in words(query.subject)) 'SUBJECT ${_argument(w)}',
    if (query.after case final d?) 'SENTSINCE ${day(DateTime(d.year, d.month, d.day - 1))}',
    if (query.before case final d?) 'SENTBEFORE ${day(DateTime(d.year, d.month, d.day + 2))}',
    if (query.unread == true) 'UNSEEN',
    if (query.starred == true) 'FLAGGED',
    if (query.hasAttachment == true) 'HEADER Content-Type "multipart/mixed"',
  ];
  if (keys.isEmpty) return null;
  // Deleted and not expunged yet: gone for every caller (`search` of the sync).
  return ['CHARSET UTF-8', 'NOT DELETED', if (below != null) 'UID 1:${below - 1}', ...keys].join(' ');
}

/// Any of [fields] holds [word]: `FROM` reads the decoded envelope, `HEADER` the raw field, which servers that match
/// `FROM` on the whole address only (GreenMail) still search by substring.
String _any(List<String> fields, String word) =>
    fields.reversed.skip(1).fold('${fields.last} ${_argument(word)}', (rest, f) => 'OR $f ${_argument(word)} $rest');

/// [text] (no control characters) as a SEARCH argument: a quoted string if it is printable ASCII, else a literal.
String _argument(String text) => RegExp(r'^[\x20-\x7e]*$').hasMatch(text)
    ? '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"'
    : '{${utf8.encode(text).length}}\n$text';

/// Whether [date] falls in the local days [query] asks for: the filter the server's day-wide SEARCH leaves to us.
bool imapInDays(SearchQuery query, DateTime date) {
  final local = date.toLocal();
  final after = query.after;
  final before = query.before;
  return (after == null || !local.isBefore(DateTime(after.year, after.month, after.day))) &&
      (before == null || local.isBefore(DateTime(before.year, before.month, before.day + 1)));
}
