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
    if (match == null) return Stream.value(const []);
    Stream<List<InboxEntry>> rows(Map<String, Set<String>> f) =>
        _db.searchDao.watchConversations(match, accountIds: query.accountIds, found: f).map(inboxEntriesOf);
    return found == null ? rows(const {}) : switchLatest(found, rows);
  }
}
