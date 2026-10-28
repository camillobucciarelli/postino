import 'package:drift/drift.dart';

import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../postino_database.dart';
import '../tables/accounts_table.dart';
import '../tables/labels_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'messages_dao.g.dart';

@DriftAccessor(tables: [Accounts, Labels, Messages, MessageLabels])
class MessagesDao extends DatabaseAccessor<PostinoDatabase>
    with _$MessagesDaoMixin {
  MessagesDao(super.attachedDatabase);

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  Future<void> applySync(
    String accountId,
    SyncBatch batch, {
    bool fullSnapshot = false,
  }) => transaction(() async {
    if (fullSnapshot) {
      // Ids go through a TEMP table, not bound variables: SQLite caps those.
      await customStatement(
        'CREATE TEMP TABLE IF NOT EXISTS snapshot_ids (id TEXT PRIMARY KEY)',
      );
      await customStatement('DELETE FROM snapshot_ids');
    }
    await this.batch((b) {
      if (fullSnapshot) {
        for (final m in batch.messages) {
          b.customStatement('INSERT OR IGNORE INTO snapshot_ids VALUES (?)', [
            m.id,
          ]);
        }
        b
          ..deleteWhere(
            messageLabels,
            (t) =>
                t.accountId.equals(accountId) &
                const CustomExpression(
                  'message_id NOT IN (SELECT id FROM snapshot_ids)',
                ),
          )
          ..deleteWhere(
            messages,
            (t) =>
                t.accountId.equals(accountId) &
                const CustomExpression(
                  'id NOT IN (SELECT id FROM snapshot_ids)',
                ),
          );
      }
      // Removals before upserts: an id both removed and upserted in one batch survives.
      for (final id in batch.removedMessageIds) {
        b
          ..deleteWhere(
            messages,
            (t) => t.accountId.equals(accountId) & t.id.equals(id),
          )
          ..deleteWhere(
            messageLabels,
            (t) => t.accountId.equals(accountId) & t.messageId.equals(id),
          );
      }
      b.insertAll(labels, [
        for (final l in batch.labels)
          LabelsCompanion.insert(
            accountId: accountId,
            id: l.id,
            name: l.name,
            kind: l.kind,
          ),
      ], mode: InsertMode.insertOrReplace);
      for (final m in batch.messages) {
        b
          ..insert(
            messages,
            MessagesCompanion.insert(
              accountId: accountId,
              id: m.id,
              messageId: m.messageId,
              conversationId: m.conversationId,
              sender: m.from,
              recipients: m.to.join(','),
              subject: m.subject,
              snippet: m.snippet,
              date: m.date.millisecondsSinceEpoch,
              isRead: m.isRead,
              isStarred: m.isStarred,
            ),
            mode: InsertMode.insertOrReplace,
          )
          ..deleteWhere(
            messageLabels,
            (t) => t.accountId.equals(accountId) & t.messageId.equals(m.id),
          )
          ..insertAll(messageLabels, [
            for (final l in m.labelIds)
              MessageLabelsCompanion.insert(
                accountId: accountId,
                messageId: m.id,
                labelId: l,
              ),
          ]);
      }
    });
  });

  /// Inbox messages of every Account, newest first, each with its Account.
  Stream<List<(AccountRow, MessageRow)>> watchUnifiedInbox() {
    final m = messages, l = messageLabels, a = accounts;
    final query = select(m).join([
      innerJoin(
        l,
        l.accountId.equalsExp(m.accountId) &
            l.messageId.equalsExp(m.id) &
            l.labelId.equals(inboxLabelId),
        useColumns: false,
      ),
      innerJoin(a, a.id.equalsExp(m.accountId)),
    ])..orderBy([OrderingTerm.desc(m.date), OrderingTerm.asc(m.id)]);
    return query.watch().map(
      (rows) => [for (final r in rows) (r.readTable(a), r.readTable(m))],
    );
  }
}
