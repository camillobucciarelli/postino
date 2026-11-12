import 'package:injectable/injectable.dart';

import '../domain/inbox_repository.dart';
import '../domain/search_query.dart';
import '../domain/search_repository.dart';
import 'fts_match.dart';
import 'postino_database.dart';
import 'row_mappers.dart';

/// The local search (#205): the full-text index of [PostinoDatabase], one row per Conversazione.
@LazySingleton(as: SearchRepository)
class SearchStore(final PostinoDatabase _db) implements SearchRepository {
  @override
  Stream<List<InboxEntry>> watchLocal(SearchQuery query) {
    final match = ftsMatch(query);
    // Nothing asked, or words that are no letters or digits: nothing the index can find.
    if (query.isEmpty || (query.hasText && match == null)) return Stream.value(const []);
    return _db.searchDao.watchConversations(query, match: match).map(inboxEntriesOf);
  }
}
