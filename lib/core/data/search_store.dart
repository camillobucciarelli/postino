import 'package:injectable/injectable.dart';

import '../domain/inbox_repository.dart';
import '../domain/search_query.dart';
import '../domain/search_repository.dart';
import 'fts_match.dart';
import 'postino_database.dart';
import 'row_mappers.dart';
import 'switch_latest.dart';

/// The local search (#205): the full-text index of [PostinoDatabase], one row per Conversazione.
@LazySingleton(as: SearchRepository)
class SearchStore(final PostinoDatabase _db) implements SearchRepository {
  @override
  Stream<List<InboxEntry>> watchLocal(SearchQuery query, {Stream<Map<String, Set<String>>>? found}) {
    final match = ftsMatch(query);
    // Nothing asked, or words that are no letters or digits: nothing the index can find.
    if (query.isEmpty || (query.hasText && match == null)) return Stream.value(const []);
    Stream<List<InboxEntry>> rows(Map<String, Set<String>> f) =>
        // Every row of a search already counts: search_dao keeps only the visible messages.
        _db.searchDao
            .watchConversations(query, match: match, found: f)
            .map((rows) => inboxEntriesOf([for (final (a, m, l) in rows) (a, m, l, true)]));
    return found == null ? rows(const {}) : switchLatest(found, rows);
  }
}
