import 'package:drift/drift.dart';

import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../postino_database.dart';
import '../tables/accounts_table.dart';
import '../tables/bodies_table.dart';
import '../tables/intents_table.dart';
import '../tables/labels_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';
import '../tables/sync_cursors_table.dart';

part 'messages_dao.g.dart';

@DriftAccessor(
  tables: [
    Accounts,
    Labels,
    Messages,
    MessageLabels,
    Bodies,
    SyncCursors,
    Intents,
  ],
)
class MessagesDao extends DatabaseAccessor<PostinoDatabase>
    with _$MessagesDaoMixin {
  MessagesDao(super.attachedDatabase);

  /// Where the Account's next incremental sync starts; null before its first sync.
  Future<String?> cursor(String accountId) async => (await (select(
    syncCursors,
  )..where((t) => t.accountId.equals(accountId))).getSingleOrNull())?.cursor;

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  /// The batch's cursor is saved in the same transaction, so data and cursor never disagree;
  /// [saveCursor] false stores a partial page of the initial sync, whose cursor must wait for the end.
  Future<void> applySync(
    String accountId,
    SyncBatch batch, {
    bool fullSnapshot = false,
    bool saveCursor = true,
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
          // Labels come with the snapshot: those gone from the Provider go too.
          ..deleteWhere(labels, (t) => t.accountId.equals(accountId))
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
          )
          ..deleteWhere(
            bodies,
            (t) =>
                t.accountId.equals(accountId) &
                const CustomExpression(
                  'message_id NOT IN (SELECT id FROM snapshot_ids)',
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
          )
          ..deleteWhere(
            bodies,
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
              senderName: Value(m.fromName),
              recipients: m.to.join('\n'),
              cc: Value(m.cc.join('\n')),
              bcc: Value(m.bcc.join('\n')),
              replyTo: Value(m.replyTo),
              references: Value(m.references.join('\n')),
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
      b.insertAll(bodies, [
        for (final MapEntry(:key, :value) in batch.bodies.entries)
          BodiesCompanion.insert(
            accountId: accountId,
            messageId: key,
            body: value.content,
            kind: Value(value.kind),
            attachments: Value(value.attachments),
          ),
      ], mode: InsertMode.insertOrReplace);
      if (saveCursor) {
        b.insert(
          syncCursors,
          SyncCursorsCompanion.insert(
            accountId: accountId,
            cursor: batch.cursor,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    await _keepIntents(accountId);
  });

  /// What the user did here wins over what the Provider still says, until the intent is replayed.
  Future<void> _keepIntents(String accountId) => customUpdate(
    'UPDATE messages SET is_read = (SELECT i.is_read FROM intents i '
    'WHERE i.account_id = messages.account_id AND i.message_id = messages.id) '
    'WHERE account_id = ?1 AND id IN '
    '(SELECT message_id FROM intents WHERE account_id = ?1 AND is_read IS NOT NULL)',
    variables: [Variable(accountId)],
    updates: {messages},
  );

  /// Every message of the Conversazioni with a message carrying [labelId] (by default the inbox), each with its Account;
  /// of every Account, or only of [accountId]. Grouping is the caller's.
  Stream<List<(AccountRow, MessageRow)>> watchMessages({
    String? accountId,
    String labelId = inboxLabelId,
  }) {
    final m = messages, a = accounts;
    final t = alias(messages, 't'), l = alias(messageLabels, 'l');
    final withLabel =
        select(t).join([
          innerJoin(
            l,
            l.accountId.equalsExp(t.accountId) &
                l.messageId.equalsExp(t.id) &
                l.labelId.equals(labelId),
            useColumns: false,
          ),
        ])..where(
          t.accountId.equalsExp(m.accountId) &
              t.conversationId.equalsExp(m.conversationId),
        );
    final query = select(m).join([innerJoin(a, a.id.equalsExp(m.accountId))])
      ..where(existsQuery(withLabel))
      ..orderBy([OrderingTerm.desc(m.date), OrderingTerm.asc(m.id)]);
    if (accountId != null) query.where(m.accountId.equals(accountId));
    return query.watch().map(
      (rows) => [for (final r in rows) (r.readTable(a), r.readTable(m))],
    );
  }

  /// The stored messages of one Conversazione, oldest first, with their body if downloaded
  /// and their label ids (system ones too: IMPORTANT, STARRED…).
  Stream<List<(MessageRow, BodyRow?, List<String>)>> watchConversation(
    String accountId,
    String conversationId,
  ) {
    final m = messages, b = bodies;
    final labelIds = CustomExpression<String>(
      '(SELECT group_concat(l.label_id, char(10)) FROM message_labels l '
      'WHERE l.account_id = messages.account_id AND l.message_id = messages.id)',
      watchedTables: [messageLabels],
    );
    final query =
        select(m).join([
            leftOuterJoin(
              b,
              b.accountId.equalsExp(m.accountId) & b.messageId.equalsExp(m.id),
            ),
          ])
          ..addColumns([labelIds])
          ..where(
            m.accountId.equals(accountId) &
                m.conversationId.equals(conversationId),
          )
          ..orderBy([OrderingTerm.asc(m.date), OrderingTerm.asc(m.id)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          (
            r.readTable(m),
            r.readTableOrNull(b),
            r.read(labelIds)?.split('\n') ?? const [],
          ),
      ],
    );
  }

  Future<void> saveBody(String accountId, String messageId, MessageBody body) =>
      into(bodies).insert(
        BodiesCompanion.insert(
          accountId: accountId,
          messageId: messageId,
          body: body.content,
          kind: Value(body.kind),
          attachments: Value(body.attachments),
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Marks the Conversazione's unread messages read here and queues the same intent for the Provider.
  Future<void> markConversationRead(String accountId, String conversationId) =>
      transaction(() async {
        final unread =
            await (selectOnly(messages)
                  ..addColumns([messages.id])
                  ..where(
                    messages.accountId.equals(accountId) &
                        messages.conversationId.equals(conversationId) &
                        messages.isRead.equals(false),
                  ))
                .map((r) => r.read(messages.id)!)
                .get();
        if (unread.isEmpty) return;
        await (update(messages)
              ..where((t) => t.accountId.equals(accountId) & t.id.isIn(unread)))
            .write(const MessagesCompanion(isRead: Value(true)));
        await batch(
          (b) => b.insertAllOnConflictUpdate(intents, [
            for (final id in unread)
              IntentsCompanion.insert(
                accountId: accountId,
                messageId: id,
                isRead: const Value(true),
              ),
          ]),
        );
      });

  /// The (Account, label) pairs of the Conversazioni that hold an unread message, system labels included
  /// (the inbox is [inboxLabelId]). Same membership as [watchMessages]: a Conversazione belongs to a label if
  /// any of its messages carries it, and is unread if any of its messages is, even another one.
  Stream<Set<(String, String)>> watchUnreadFolders() {
    final m = messages, l = messageLabels, u = alias(messages, 'u');
    final unreadInConversation = select(u)
      ..where(
        (u) =>
            u.accountId.equalsExp(m.accountId) &
            u.conversationId.equalsExp(m.conversationId) &
            u.isRead.equals(false),
      );
    final query =
        selectOnly(l, distinct: true).join([
            innerJoin(
              m,
              m.accountId.equalsExp(l.accountId) & m.id.equalsExp(l.messageId),
              useColumns: false,
            ),
          ])
          ..addColumns([l.accountId, l.labelId])
          ..where(existsQuery(unreadInConversation));
    return query.watch().map(
      (rows) => {
        for (final r in rows) (r.read(l.accountId)!, r.read(l.labelId)!),
      },
    );
  }

  /// The Account's own Etichette, by name.
  Stream<List<LabelRow>> watchLabels(String accountId) =>
      (select(labels)
            ..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.kind.equalsValue(LabelKind.etichetta),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();
}
