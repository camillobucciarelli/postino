import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/inbox_repository.dart';
import '../domain/mail_provider.dart';
import '../domain/message.dart';
import 'postino_database.dart';

@lazySingleton
class MailStore implements InboxRepository {
  MailStore(this._db);
  final PostinoDatabase _db;

  Future<void> addAccount(Account a) => _db
      .into(_db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: a.id,
          address: a.address,
          provider: a.provider,
          color: a.color,
          position: a.position,
          status: a.status,
        ),
        mode: InsertMode.insertOrReplace,
      );

  Future<List<Account>> accounts() async => [
    for (final r in await (_db.select(
      _db.accounts,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get())
      _account(r),
  ];

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  Future<void> applySync(
    String accountId,
    SyncBatch batch, {
    bool fullSnapshot = false,
  }) => _db.transaction(() async {
    if (fullSnapshot) {
      // Ids go through a TEMP table, not bound variables: SQLite caps those.
      await _db.customStatement(
        'CREATE TEMP TABLE IF NOT EXISTS snapshot_ids (id TEXT PRIMARY KEY)',
      );
      await _db.customStatement('DELETE FROM snapshot_ids');
    }
    await _db.batch((b) {
      if (fullSnapshot) {
        for (final m in batch.messages) {
          b.customStatement('INSERT OR IGNORE INTO snapshot_ids VALUES (?)', [
            m.id,
          ]);
        }
        b
          ..deleteWhere(
            _db.messageLabels,
            (t) =>
                t.accountId.equals(accountId) &
                const CustomExpression(
                  'message_id NOT IN (SELECT id FROM snapshot_ids)',
                ),
          )
          ..deleteWhere(
            _db.messages,
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
            _db.messages,
            (t) => t.accountId.equals(accountId) & t.id.equals(id),
          )
          ..deleteWhere(
            _db.messageLabels,
            (t) => t.accountId.equals(accountId) & t.messageId.equals(id),
          );
      }
      b.insertAll(_db.labels, [
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
            _db.messages,
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
            _db.messageLabels,
            (t) => t.accountId.equals(accountId) & t.messageId.equals(m.id),
          )
          ..insertAll(_db.messageLabels, [
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

  @override
  Stream<List<InboxEntry>> watchUnifiedInbox() {
    final m = _db.messages, l = _db.messageLabels, a = _db.accounts;
    final query = _db.select(m).join([
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
      (rows) => [
        for (final r in rows)
          InboxEntry(
            account: _account(r.readTable(a)),
            message: _message(r.readTable(m)),
          ),
      ],
    );
  }

  static Account _account(AccountRow r) => Account(
    id: r.id,
    address: r.address,
    provider: r.provider,
    color: r.color,
    position: r.position,
    status: r.status,
  );

  static Message _message(MessageRow r) => Message(
    id: r.id,
    messageId: r.messageId,
    conversationId: r.conversationId,
    labelIds: const [inboxLabelId],
    isRead: r.isRead,
    isStarred: r.isStarred,
    from: r.sender,
    to: r.recipients.split(','),
    subject: r.subject,
    snippet: r.snippet,
    date: DateTime.fromMillisecondsSinceEpoch(r.date, isUtc: true),
  );
}

@module
abstract class MailStoreModule {
  /// The UI sees the store only through [InboxRepository].
  @lazySingleton
  InboxRepository inboxRepository(MailStore store) => store;
}
