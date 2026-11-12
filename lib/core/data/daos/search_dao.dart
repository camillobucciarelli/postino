import 'package:drift/drift.dart';

import '../../domain/message.dart' show spamLabelId;
import '../../domain/search_query.dart';
import '../postino_database.dart';
import '../tables/accounts_table.dart';
import '../tables/bodies_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'search_dao.g.dart';

/// Looks messages up in the full-text index (#205) and by criteria (#206); the index itself is kept by triggers and
/// by `BodiesDao`.
@DriftAccessor(tables: [Accounts, Messages, MessageLabels, Bodies])
class SearchDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$SearchDaoMixin {
  /// Every message of the Conversazioni that satisfy [query], newest first, with its Account and label ids. [match] is
  /// the FTS5 expression of its text (see `ftsMatch`), null when it has none: then only the criteria count.
  /// Each criterion is looked up on its own, as the list does: a Conversazione is a hit if it has a message that
  /// matches the text, one that is unread, one with the Stella, one with attachments (known to have), one in the
  /// dates. Of every Account, or only of those in `accountIds`, or whose address holds one of `accountNames`.
  /// Grouping is the caller's. [match] holds only quoted letters and digits and the rest are numbers, so all is
  /// safe inside the SQL literal; the Account names are bound.
  Stream<List<(AccountRow, MessageRow, List<String>)>> watchConversations(SearchQuery query, {String? match}) {
    final m = messages;
    final a = accounts;
    final labelIds = attachedDatabase.messagesDao.labelIds;
    // Spam is in no view but its own (see the glossary): neither a hit nor a row of a Conversazione.
    String notSpam(String row) =>
        'NOT EXISTS (SELECT 1 FROM message_labels sl WHERE sl.account_id = $row.account_id AND sl.message_id = $row.id '
        "AND sl.label_id = '$spamLabelId')";
    // The Conversazioni having a (not Spam) message with [where].
    String having(String where) =>
        '(messages.account_id, messages.conversation_id) IN (SELECT h.account_id, h.conversation_id FROM messages h '
        'WHERE ${notSpam('h')} AND $where)';
    int dayStart(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final (after, before) = (query.after, query.before);
    final conditions = [
      notSpam('messages'),
      if (match != null)
        '(messages.account_id, messages.conversation_id) IN (SELECT h.account_id, h.conversation_id FROM search_index '
            "JOIN messages h ON h.rowid = search_index.rowid WHERE search_index MATCH '$match' AND ${notSpam('h')})",
      if (query.unread ?? false) having('h.is_read = 0'),
      if (query.starred ?? false) having('h.is_starred = 1'),
      if (query.hasAttachment ?? false) having('h.has_attachments = 1'),
      // The local day: from its midnight to the next one (a day is not always 24 hours).
      if (after != null || before != null)
        having(
          [
            if (after != null) 'h.date >= ${dayStart(after)}',
            if (before != null) 'h.date < ${dayStart(DateTime(before.year, before.month, before.day + 1))}',
          ].join(' AND '),
        ),
    ];
    final hits = CustomExpression<bool>(conditions.join(' AND '), watchedTables: [messages, bodies, messageLabels]);
    final select = this.select(m).join([innerJoin(a, a.id.equalsExp(m.accountId))])
      ..addColumns([labelIds])
      ..where(hits)
      ..orderBy([OrderingTerm.desc(m.date), OrderingTerm.asc(m.id)]);
    if (query.accountIds.isNotEmpty) select.where(m.accountId.isIn(query.accountIds));
    if (query.accountNames.isNotEmpty) {
      // instr, not LIKE: a name with `_` or `%` is what it says, not a pattern.
      select.where(
        Expression.or([
          for (final n in query.accountNames)
            FunctionCallExpression<int>('instr', [
              a.address.lower(),
              Variable<String>(n.toLowerCase()),
            ]).isBiggerThanValue(0),
        ]),
      );
    }
    return select.watch().map(
      (rows) => [for (final r in rows) (r.readTable(a), r.readTable(m), r.read(labelIds)?.split('\n') ?? const [])],
    );
  }

  /// Merges the index's segments into one: the entries of removed messages leave the file for good (their pages are
  /// wiped, `secure_delete`), what Rimozione di un Account (#174) promises.
  Future<void> optimize() => customStatement("INSERT INTO search_index (search_index) VALUES ('optimize')");
}
