import '../../domain/message.dart';
import '../../domain/provider_search_page.dart';
import '../../domain/search_query.dart';
import '../json_objects.dart';
import 'gmail_http.dart';

/// Results per page: Gmail's quota allows about 6 searches a minute per user at this size.
const _page = 50;

/// One page of the search for [query] (#207): `messages.list` (never Spam nor Cestino, Gmail's default), then the
/// headers of those not in [stored] through [fetch], which is the sync's (`format=metadata`, null for one gone).
Future<ProviderSearchPage> gmailSearch(
  GmailHttp gmail,
  SearchQuery query, {
  required String? pageToken,
  required Set<String> stored,
  required Future<List<Message>> Function(Iterable<String> ids) fetch,
}) async {
  final q = gmailQuery(query);
  if (q.isEmpty) return const ProviderSearchPage();
  final r = await gmail.get('messages', query: {'q': q, 'maxResults': '$_page', 'pageToken': ?pageToken});
  final found = jsonObjects(r['messages']).toList();
  final messages = await fetch([
    for (final m in found)
      if (!stored.contains(m['id'])) m['id'] as String,
  ]);
  // Newest first, as Gmail listed them.
  final order = {for (final (i, m) in found.indexed) m['id']: i};
  return ProviderSearchPage(
    messages: messages..sort((a, b) => order[a.id]!.compareTo(order[b.id]!)),
    conversationIds: {for (final m in found) m['threadId'] as String},
    nextPageToken: r['nextPageToken'] as String?,
  );
}

/// Gmail's `q` for [query] (#207, `docs/research/ricerca-server-per-provider.md`); empty when there is nothing to
/// look for. Every value the user typed is quoted, so it is never an operator (`in:spam`, `-x`, `OR`); a quote
/// inside it, which Gmail cannot escape, becomes a space. The words of sender, recipients and subject each go on
/// their own, as the local search reads them; Gmail matches them as whole words, not as word beginnings like the
/// local index (`fatt` does not find «fattura» there). The criteria hold for one message, while the local search
/// takes them per Conversazione (a read «Preventivo» answered by an unread reply): the Gmail API has no search over a
/// whole thread.
// ponytail: per-message criteria on the Provider; one query per criterion and an intersection if QA misses threads. The days are epoch seconds at the edges of the local day: Gmail reads
/// `after:YYYY/MM/DD` in PST.
String gmailQuery(SearchQuery query) {
  String quoted(String s) => '"${s.replaceAll('"', ' ').trim().replaceAll(RegExp(r'\s+'), ' ')}"';
  List<String> words(String? s) => [
    for (final w in (s ?? '').replaceAll('"', ' ').split(RegExp(r'\s+')))
      if (w.isNotEmpty) quoted(w),
  ];
  int epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
  final phrase = query.phrase == null ? '""' : quoted(query.phrase!);
  return [
    ...query.terms.expand(words),
    if (phrase != '""') phrase,
    for (final w in words(query.from)) 'from:$w',
    for (final w in words(query.to)) '{to:$w cc:$w}',
    for (final w in words(query.subject)) 'subject:$w',
    if (query.after case final d?) 'after:${epoch(DateTime(d.year, d.month, d.day))}',
    if (query.before case final d?) 'before:${epoch(DateTime(d.year, d.month, d.day + 1))}',
    if (query.unread == true) 'is:unread',
    if (query.starred == true) 'is:starred',
    if (query.hasAttachment == true) 'has:attachment',
  ].join(' ');
}
