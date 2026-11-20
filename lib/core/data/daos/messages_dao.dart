import 'package:drift/drift.dart';

import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../postino_database.dart';
import '../search_index.dart';
import '../tables/accounts_table.dart';
import '../tables/bodies_table.dart';
import '../tables/conflicts_table.dart';
import '../tables/intents_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';
import '../tables/sync_cursors_table.dart';

part 'messages_dao.g.dart';

@DriftAccessor(tables: [Accounts, Messages, MessageLabels, Bodies, SyncCursors, Intents, Conflicts])
class MessagesDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$MessagesDaoMixin {
  /// Where the Account's next incremental sync starts; null before its first sync.
  Future<String?> cursor(String accountId) async =>
      (await (select(syncCursors)..where((t) => t.accountId.equals(accountId))).getSingleOrNull())?.cursor;

  /// The Provider ids of the Account's messages in cache.
  Future<List<String>> ids(String accountId) =>
      (selectOnly(messages)
            ..addColumns([messages.id])
            ..where(messages.accountId.equals(accountId)))
          .map((r) => r.read(messages.id)!)
          .get();

  /// True when the Account has the message with Provider id [id] in cache.
  Future<bool> exists(String accountId, String id) async =>
      (await (select(messages)
                ..where((t) => t.accountId.equals(accountId) & t.id.equals(id))
                ..limit(1))
              .get())
          .isNotEmpty;

  /// The Message-ID (RFC 5322) of the message with Provider id [id]; null if the Account has no such message.
  Future<String?> rfcMessageId(String accountId, String id) async =>
      (await (select(messages)
                ..where((t) => t.accountId.equals(accountId) & t.id.equals(id))
                ..limit(1))
              .getSingleOrNull())
          ?.messageId;

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  /// The batch's cursor is saved in the same transaction, so data and cursor never disagree;
  /// [saveCursor] false stores a partial page of the initial sync, whose cursor must wait for the end.
  /// [bodyTexts]: the `searchableTextsOf` the batch's bodies, when the caller made them before its own transaction.
  Future<void> applySync(
    String accountId,
    SyncBatch batch, {
    bool fullSnapshot = false,
    bool saveCursor = true,
    Map<String, String>? bodyTexts,
  }) async {
    // Before this transaction; MailStore makes them before its own, so other writers do not wait for the parsing (#221).
    final texts = bodyTexts ?? await searchableTextsOf(batch.bodies);
    return transaction(() async {
      if (fullSnapshot) {
        // Ids go through a TEMP table, not bound variables: SQLite caps those.
        await customStatement('CREATE TEMP TABLE IF NOT EXISTS snapshot_ids (id TEXT PRIMARY KEY)');
        await customStatement('DELETE FROM snapshot_ids');
      }
      final labelsDao = attachedDatabase.labelsDao;
      final bodiesDao = attachedDatabase.bodiesDao;
      await this.batch((b) {
        if (fullSnapshot) {
          // Left behind by the sync (#252): the stored copy stays until its retry, its Bozza too.
          for (final id in [for (final m in batch.messages) m.id, ...batch.deferredMessageIds]) {
            b.customStatement('INSERT OR IGNORE INTO snapshot_ids VALUES (?)', [id]);
          }
          b
            ..deleteWhere(
              messageLabels,
              (t) =>
                  t.accountId.equals(accountId) &
                  const CustomExpression('message_id NOT IN (SELECT id FROM snapshot_ids)'),
            )
            ..deleteWhere(
              messages,
              (t) => t.accountId.equals(accountId) & const CustomExpression('id NOT IN (SELECT id FROM snapshot_ids)'),
            );
          bodiesDao.deleteNotInSnapshotIn(b, accountId);
        }
        // Removals before upserts: an id both removed and upserted in one batch survives.
        for (final id in batch.removedMessageIds) {
          b
            ..deleteWhere(messages, (t) => t.accountId.equals(accountId) & t.id.equals(id))
            ..deleteWhere(messageLabels, (t) => t.accountId.equals(accountId) & t.messageId.equals(id));
          bodiesDao.deleteIn(b, accountId, id);
        }
        // The batch's list is the whole one: those gone from the Provider go too.
        if (batch.labels case final labels?) {
          labelsDao
            ..deleteAllIn(b, accountId)
            ..upsertAllIn(b, accountId, labels);
        }
        for (final m in batch.messages) {
          final row = MessagesCompanion.insert(
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
            // Unknown does not erase what a body or an earlier sync already said.
            hasAttachments: Value.absentIfNull(m.hasAttachments),
          );
          b
            // An upsert, not a replace: the row keeps its rowid, which is the id of its entry in the search index.
            ..insert(messages, row, onConflict: DoUpdate((_) => row))
            ..deleteWhere(messageLabels, (t) => t.accountId.equals(accountId) & t.messageId.equals(m.id))
            ..insertAll(messageLabels, [
              for (final l in m.labelIds)
                MessageLabelsCompanion.insert(accountId: accountId, messageId: m.id, labelId: l),
            ]);
          // A header-only guess does not undo what the body already said.
          if (m.hasAttachments != null) bodiesDao.correctHasAttachmentsIn(b, accountId, m.id);
        }
        bodiesDao.upsertAllIn(b, accountId, batch.bodies, texts);
        if (saveCursor) {
          b.insert(
            syncCursors,
            SyncCursorsCompanion.insert(accountId: accountId, cursor: batch.cursor),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      await _keepIntents(accountId, {for (final m in batch.messages) m.id});
    });
  }

  /// What the user did here wins over what the Provider still says: until its voce is replayed, and while its
  /// Conflitto is open (ADR 0008).
  // ponytail: one read-and-write per voce and Conflitto; set-based SQL per attribute if the queue ever grows big.
  /// [synced]: the messages the batch brought, whose values here are now the Provider's.
  Future<void> _keepIntents(String accountId, Set<String> synced) async {
    // A message gone (removed, or absent from a full snapshot) closes its Conflitti: nothing left to decide.
    await customUpdate(
      'DELETE FROM conflicts WHERE account_id = ?1 '
      'AND message_id NOT IN (SELECT id FROM messages WHERE account_id = ?1)',
      variables: [Variable(accountId)],
      updates: {conflicts},
      updateKind: UpdateKind.delete,
    );
    final attributes = attachedDatabase.attributesDao;
    final voci = await (select(intents)..where((t) => t.accountId.equals(accountId))).get();
    // Before any overlay: the batch's value of a queued attribute is the Provider's.
    for (final v in voci) {
      if (!synced.contains(v.messageId)) continue;
      if (await attributes.read(accountId, v.messageId, v.attribute) case final provider?) {
        await (update(intents)..where(
              (t) => t.accountId.equals(accountId) & t.messageId.equals(v.messageId) & t.attribute.equals(v.attribute),
            ))
            .write(IntentsCompanion(synced: Value(provider)));
      }
    }
    for (final c in await (select(conflicts)..where((t) => t.accountId.equals(accountId))).get()) {
      Expression<bool> key($ConflictsTable t) =>
          t.accountId.equals(accountId) & t.messageId.equals(c.messageId) & t.attribute.equals(c.attribute);
      // Changed again elsewhere: «tieni quella del Provider» must bring the latest value, and once the Provider has
      // the local one there is nothing left to decide.
      if (synced.contains(c.messageId)) {
        if (await attributes.read(accountId, c.messageId, c.attribute) case final provider?
            when provider != c.provider) {
          if (provider == c.local) {
            await (delete(conflicts)..where(key)).go();
            continue;
          }
          await (update(conflicts)..where(key)).write(ConflictsCompanion(provider: Value(provider)));
        }
      }
      await attributes.write(accountId, c.messageId, c.attribute, c.local);
    }
    // After the Conflitti: an Azione queued over one shows here.
    for (final v in voci) {
      await attributes.write(accountId, v.messageId, v.attribute, v.wanted);
    }
  }

  /// Every message of the Conversazioni with a message carrying [labelId] (by default the inbox) that counts in that
  /// view (see [_countsIn]: one in the Cestino or Spam counts only there), each with its Account;
  /// of every Account, or only of [accountId], with each message's label ids and whether it counts in the view itself
  /// (a message in the Cestino does not make its Conversazione unread in the inbox). Grouping is the caller's.
  Stream<List<(AccountRow, MessageRow, List<String>, bool)>> watchMessages({
    String? accountId,
    String labelId = inboxLabelId,
  }) {
    final m = messages;
    final a = accounts;
    final t = alias(messages, 't');
    final l = alias(messageLabels, 'l');
    final withLabel =
        select(t).join([
          innerJoin(
            l,
            l.accountId.equalsExp(t.accountId) & l.messageId.equalsExp(t.id) & l.labelId.equals(labelId),
            useColumns: false,
          ),
        ])..where(
          t.accountId.equalsExp(m.accountId) &
              t.conversationId.equalsExp(m.conversationId) &
              _countsIn(t, Variable(labelId)),
        );
    final counts = _countsIn(m, Variable(labelId));
    final query = select(m).join([innerJoin(a, a.id.equalsExp(m.accountId))])
      ..addColumns([labelIds, counts])
      ..where(existsQuery(withLabel))
      ..orderBy([OrderingTerm.desc(m.date), OrderingTerm.asc(m.id)]);
    if (accountId != null) query.where(m.accountId.equals(accountId));
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          (r.readTable(a), r.readTable(m), r.read(labelIds)?.split('\n') ?? const [], r.read(counts) ?? true),
      ],
    );
  }

  /// Whether the message [t], carrying [labelId], makes its Conversazione belong to that view. Cestino and Spam are
  /// views of their own (see the glossary): a message there keeps its other labels (Gmail, or the local Elimina until
  /// the Provider moves it) but counts in no other view. With both, the Cestino wins: Elimina from Spam adds TRASH
  /// here before the Provider takes SPAM away.
  Expression<bool> _countsIn($MessagesTable t, Expression<String> labelId) {
    final x = alias(messageLabels, 'x');
    return notExistsQuery(
      select(x)..where(
        (x) =>
            x.accountId.equalsExp(t.accountId) &
            x.messageId.equalsExp(t.id) &
            (x.labelId.equals(trashLabelId) & labelId.equals(trashLabelId).not() |
                x.labelId.equals(spamLabelId) & labelId.isIn(const [spamLabelId, trashLabelId]).not()),
      ),
    );
  }

  /// The label ids of a `messages` row, one per line.
  CustomExpression<String> get labelIds => CustomExpression<String>(
    '(SELECT group_concat(l.label_id, char(10)) FROM message_labels l '
    'WHERE l.account_id = messages.account_id AND l.message_id = messages.id)',
    watchedTables: [messageLabels],
  );

  /// The stored messages of one Conversazione, oldest first, with their body if downloaded
  /// and their label ids (system ones too: IMPORTANT, STARRED…).
  Stream<List<(MessageRow, BodyRow?, List<String>)>> watchConversation(String accountId, String conversationId) {
    final m = messages;
    final b = bodies;
    final query = select(m).join([leftOuterJoin(b, b.accountId.equalsExp(m.accountId) & b.messageId.equalsExp(m.id))])
      ..addColumns([labelIds])
      ..where(m.accountId.equals(accountId) & m.conversationId.equals(conversationId))
      ..orderBy([OrderingTerm.asc(m.date), OrderingTerm.asc(m.id)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows) (r.readTable(m), r.readTableOrNull(b), r.read(labelIds)?.split('\n') ?? const []),
      ],
    );
  }

  /// One stored message with its label ids; null while it is not stored (or gone).
  Stream<(MessageRow, List<String>)?> watchOne(String accountId, String messageId) {
    final m = messages;
    final query = select(m).join([])
      ..addColumns([labelIds])
      ..where(m.accountId.equals(accountId) & m.id.equals(messageId));
    return query.watchSingleOrNull().map(
      (r) => r == null ? null : (r.readTable(m), r.read(labelIds)?.split('\n') ?? const <String>[]),
    );
  }

  /// The Conversazione's unread messages, by Provider-side id.
  Future<List<String>> unreadIn(String accountId, String conversationId) =>
      (selectOnly(messages)
            ..addColumns([messages.id])
            ..where(
              messages.accountId.equals(accountId) &
                  messages.conversationId.equals(conversationId) &
                  messages.isRead.equals(false),
            ))
          .map((r) => r.read(messages.id)!)
          .get();

  /// The (Account, label) pairs of the Conversazioni that hold an unread message, system labels included
  /// (the inbox is [inboxLabelId]). Same membership as [watchMessages]: a Conversazione belongs to a label if
  /// any of its messages carries it and counts there ([_countsIn]), and is unread if any of its messages is, even
  /// another one.
  Stream<Set<(String, String)>> watchUnreadFolders() {
    final m = messages;
    final l = messageLabels;
    final u = alias(messages, 'u');
    final unreadInConversation = select(u)
      ..where(
        (u) =>
            u.accountId.equalsExp(m.accountId) &
            u.conversationId.equalsExp(m.conversationId) &
            u.isRead.equals(false) &
            _countsIn(u, l.labelId),
      );
    final query =
        selectOnly(
            l,
            distinct: true,
          ).join([innerJoin(m, m.accountId.equalsExp(l.accountId) & m.id.equalsExp(l.messageId), useColumns: false)])
          ..addColumns([l.accountId, l.labelId])
          ..where(_countsIn(m, l.labelId) & existsQuery(unreadInConversation));
    return query.watch().map((rows) => {for (final r in rows) (r.read(l.accountId)!, r.read(l.labelId)!)});
  }

  /// Removes the Account's messages, their labels and sync cursor (Rimozione di un Account, #174).
  Future<void> deleteByAccount(String accountId) async {
    await (delete(messages)..where((t) => t.accountId.equals(accountId))).go();
    await (delete(messageLabels)..where((t) => t.accountId.equals(accountId))).go();
    await (delete(syncCursors)..where((t) => t.accountId.equals(accountId))).go();
  }
}
