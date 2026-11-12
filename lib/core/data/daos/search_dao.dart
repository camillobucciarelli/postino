import 'package:drift/drift.dart';

import '../../domain/message.dart' show spamLabelId;
import '../postino_database.dart';
import '../tables/accounts_table.dart';
import '../tables/bodies_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'search_dao.g.dart';

/// Looks messages up in the full-text index (#205); the index itself is kept by triggers and by `BodiesDao`.
@DriftAccessor(tables: [Accounts, Messages, MessageLabels, Bodies])
class SearchDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$SearchDaoMixin {
  /// Every message of the Conversazioni with a message matching the FTS5 expression [match] (see `ftsMatch`), newest
  /// first, with its Account and label ids; of every Account, or only of [accountIds] when not empty.
  /// Grouping is the caller's. [match] holds only quoted letters and digits, so it is safe inside the SQL literal.
  /// The Conversazioni of [found] (Account id to conversation ids: found on the Provider, #207) are hits too.
  Stream<List<(AccountRow, MessageRow, List<String>)>> watchConversations(
    String match, {
    Set<String> accountIds = const {},
    Map<String, Set<String>> found = const {},
  }) {
    final m = messages;
    final a = accounts;
    final labelIds = attachedDatabase.messagesDao.labelIds;
    // The hits are looked up once, not per row: a Conversazione is a hit if any of its messages is.
    // Spam is in no view but its own (see the glossary): neither a hit nor a row of a Conversazione.
    String notSpam(String row) =>
        'NOT EXISTS (SELECT 1 FROM message_labels sl WHERE sl.account_id = $row.account_id AND sl.message_id = $row.id '
        "AND sl.label_id = '$spamLabelId')";
    final hits = CustomExpression<bool>(
      '(messages.account_id, messages.conversation_id) IN (SELECT h.account_id, h.conversation_id FROM search_index '
      "JOIN messages h ON h.rowid = search_index.rowid WHERE search_index MATCH '$match' AND ${notSpam('h')})",
      watchedTables: [messages, bodies, messageLabels],
    );
    final onProvider = [
      for (final MapEntry(key: account, value: ids) in found.entries)
        if (ids.isNotEmpty) m.accountId.equals(account) & m.conversationId.isIn(ids),
    ];
    final query = select(m).join([innerJoin(a, a.id.equalsExp(m.accountId))])
      ..addColumns([labelIds])
      ..where(Expression.or([hits, ...onProvider]) & CustomExpression<bool>(notSpam('messages')))
      ..orderBy([OrderingTerm.desc(m.date), OrderingTerm.asc(m.id)]);
    if (accountIds.isNotEmpty) query.where(m.accountId.isIn(accountIds));
    return query.watch().map(
      (rows) => [for (final r in rows) (r.readTable(a), r.readTable(m), r.read(labelIds)?.split('\n') ?? const [])],
    );
  }

  /// Merges the index's segments into one: the entries of removed messages leave the file for good (their pages are
  /// wiped, `secure_delete`), what Rimozione di un Account (#174) promises.
  Future<void> optimize() => customStatement("INSERT INTO search_index (search_index) VALUES ('optimize')");
}
