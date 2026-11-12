import '../../domain/message.dart';
import '../../domain/search_query.dart';

/// The `$search` of [query] on `/me/messages` (#209, `docs/research/ricerca-server-per-provider.md`), outer quotes
/// included; empty when there is nothing Graph can look for (only unread or Stella: [graphSearchKeeps] filters
/// those, there is nothing to filter).
///
/// One KQL expression in one pair of quotes, as Graph wants a property-scoped `$search`; every value the user typed
/// is a phrase in escaped quotes (`\"…\"`), so it is never an operator (`OR`, `NOT`, `from:`). A quote or a
/// backslash inside it, which would end the phrase or the expression, becomes a space. The words of sender,
/// recipients and subject each go on their own, as the local search reads them; free words look in sender, subject
/// and body, Graph's default, not in the recipients. The days are widened by one on each side, as KQL reads them in
/// UTC: [graphSearchKeeps] holds the user's local day.
String graphKql(SearchQuery query) {
  final unsafe = RegExp(r'["\\]');
  String quoted(String s) => '\\"${s.replaceAll(unsafe, ' ').trim().replaceAll(RegExp(r'\s+'), ' ')}\\"';
  List<String> words(String? s) => [
    for (final w in (s ?? '').replaceAll(unsafe, ' ').split(RegExp(r'\s+')))
      if (w.isNotEmpty) quoted(w),
  ];
  String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final phrase = query.phrase == null ? null : quoted(query.phrase!);
  final clauses = [
    ...query.terms.expand(words),
    if (phrase != null && phrase != quoted('')) phrase,
    for (final w in words(query.from)) 'from:$w',
    for (final w in words(query.to)) '(to:$w OR cc:$w)',
    for (final w in words(query.subject)) 'subject:$w',
    if (query.hasAttachment == true) 'hasAttachments:true',
    if (query.after case final d?) 'received>=${day(DateTime(d.year, d.month, d.day - 1))}',
    if (query.before case final d?) 'received<=${day(DateTime(d.year, d.month, d.day + 1))}',
  ];
  return clauses.isEmpty ? '' : '"${clauses.join(' AND ')}"';
}

/// Whether a message Graph found for [query] stays: what `$search` cannot filter (unread, Stella; `$filter` does not
/// go with it on messages) or reads in UTC (the days) is checked here. Per message, as on Gmail: a read message
/// answered by an unread reply is not a match.
bool graphSearchKeeps(SearchQuery query, Message m) =>
    (query.unread != true || !m.isRead) &&
    (query.starred != true || m.isStarred) &&
    (query.hasAttachment != true || m.hasAttachments == true) &&
    (query.after == null || !m.date.isBefore(DateTime(query.after!.year, query.after!.month, query.after!.day))) &&
    (query.before == null || m.date.isBefore(DateTime(query.before!.year, query.before!.month, query.before!.day + 1)));
