import 'package:drift/drift.dart';

import '../../domain/message.dart';
import '../postino_database.dart';
import '../tables/accounts_table.dart';
import '../tables/bodies_table.dart';
import '../tables/drafts_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'drafts_dao.g.dart';

/// SQL: the message `m` carries the DRAFT label.
const _inFolder =
    'EXISTS (SELECT 1 FROM message_labels l WHERE l.account_id = m.account_id '
    "AND l.message_id = m.id AND l.label_id = '$draftLabelId')";

@DriftAccessor(tables: [Drafts, Accounts, Messages, MessageLabels, Bodies])
class DraftsDao extends DatabaseAccessor<PostinoDatabase>
    with _$DraftsDaoMixin {
  DraftsDao(super.attachedDatabase);

  /// Writes the content and marks the Bozza pending; the synced and remoteKnown marks stay.
  /// [updatedAt] is also the version the ack matches, so it is bumped past the previous save's when the clock has not moved.
  // ponytail: a version in the timestamp, no revision column; a clock set back keeps counting up from the last save.
  Future<void> save(
    String accountId,
    OutgoingMessage draft, {
    required int updatedAt,
  }) => transaction(() async {
    final prev = (await byId(accountId, draft.messageId))?.updatedAt;
    if (prev != null && updatedAt <= prev) updatedAt = prev + 1;
    final content = DraftsCompanion(
      recipients: Value(draft.to.join('\n')),
      cc: Value(draft.cc.join('\n')),
      bcc: Value(draft.bcc.join('\n')),
      subject: Value(draft.subject),
      body: Value(draft.body),
      updatedAt: Value(updatedAt),
      pending: const Value(true),
    );
    await into(drafts).insert(
      DraftsCompanion.insert(
        accountId: accountId,
        messageId: draft.messageId,
        recipients: draft.to.join('\n'),
        cc: draft.cc.join('\n'),
        bcc: draft.bcc.join('\n'),
        subject: draft.subject,
        body: draft.body,
        updatedAt: updatedAt,
        pending: true,
        synced: false,
        remoteKnown: false,
      ),
      onConflict: DoUpdate((_) => content),
    );
  });

  /// A Bozza taken over from the Provider (another client's, or a newer version of one here with nothing
  /// pending): already synced, nothing pending; it replaces the local row.
  Future<void> adopt(
    String accountId,
    OutgoingMessage draft, {
    required int updatedAt,
  }) => into(drafts).insert(
    DraftsCompanion.insert(
      accountId: accountId,
      messageId: draft.messageId,
      recipients: draft.to.join('\n'),
      cc: draft.cc.join('\n'),
      bcc: draft.bcc.join('\n'),
      subject: draft.subject,
      body: draft.body,
      updatedAt: updatedAt,
      pending: false,
      synced: true,
      remoteKnown: true,
    ),
    mode: InsertMode.insertOrReplace,
  );

  Future<DraftRow?> byId(String accountId, String messageId) =>
      (select(drafts)..where(
            (t) =>
                t.accountId.equals(accountId) & t.messageId.equals(messageId),
          ))
          .getSingleOrNull();

  /// The Account's local Bozze, newest first.
  Stream<List<DraftRow>> watch(String accountId) =>
      (select(drafts)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  /// What the Bozze folder shows: the local rows (as messages: id and Conversazione are the Message-ID, the body
  /// stands as snippet) and the Provider's DRAFT messages without a local row, newest first; [local] tells them apart.
  Stream<List<(MessageRow, bool local)>> watchAll(String accountId) =>
      customSelect(
        'SELECT d.account_id, d.message_id AS id, d.message_id, d.message_id AS conversation_id, '
        'a.address AS sender, NULL AS sender_name, d.recipients, d.cc, d.bcc, d.subject, d.body AS snippet, '
        'd.updated_at AS date, 1 AS is_read, 0 AS is_starred, 1 AS local '
        'FROM drafts d JOIN accounts a ON a.id = d.account_id WHERE d.account_id = ?1 '
        'UNION ALL '
        'SELECT m.account_id, m.id, m.message_id, m.conversation_id, m.sender, m.sender_name, '
        'm.recipients, m.cc, m.bcc, m.subject, m.snippet, m.date, m.is_read, m.is_starred, 0 '
        // A Bozza without a Message-ID cannot be addressed (route, update): not listed.
        "FROM messages m WHERE m.account_id = ?1 AND m.message_id <> '' AND $_inFolder "
        'AND m.message_id NOT IN (SELECT message_id FROM drafts WHERE account_id = ?1) '
        'ORDER BY date DESC',
        variables: [Variable(accountId)],
        readsFrom: {drafts, accounts, messages, messageLabels},
      ).watch().map(
        (rows) => [
          for (final r in rows) (messages.map(r.data), r.read<bool>('local')),
        ],
      );

  /// The Provider's DRAFT message with this Message-ID, with its body if downloaded.
  Future<(MessageRow, BodyRow?)?> remote(
    String accountId,
    String messageId,
  ) async {
    final m = alias(messages, 'm'), b = bodies;
    final r =
        await (select(m).join([
                leftOuterJoin(
                  b,
                  b.accountId.equalsExp(m.accountId) &
                      b.messageId.equalsExp(m.id),
                ),
              ])
              ..where(
                m.accountId.equals(accountId) &
                    m.messageId.equals(messageId) &
                    const CustomExpression<bool>(_inFolder),
              )
              ..limit(1))
            .getSingleOrNull();
    return r == null ? null : (r.readTable(m), r.readTableOrNull(b));
  }

  Future<List<DraftRow>> pending(String accountId) =>
      (select(drafts)..where(
            (t) => t.accountId.equals(accountId) & t.pending.equals(true),
          ))
          .get();

  /// The content of [updatedAt] reached the Provider: the Bozza exists there from now on (the next save is an
  /// update, also when it was edited meanwhile), and is no longer pending unless edited meanwhile.
  Future<void> synced(String accountId, String messageId, int updatedAt) =>
      transaction(() async {
        Expression<bool> row(Drafts t) =>
            t.accountId.equals(accountId) & t.messageId.equals(messageId);
        await (update(
          drafts,
        )..where(row)).write(const DraftsCompanion(synced: Value(true)));
        await (update(drafts)
              ..where((t) => row(t) & t.updatedAt.equals(updatedAt)))
            .write(const DraftsCompanion(pending: Value(false)));
      });

  Future<void> remove(String accountId, String messageId) =>
      (delete(drafts)..where(
            (t) =>
                t.accountId.equals(accountId) & t.messageId.equals(messageId),
          ))
          .go();

  /// After a sync: a Bozza the Provider lists as DRAFT is remoteKnown; one it listed before and no longer
  /// does, with nothing pending here, was deleted or sent elsewhere, so it goes.
  // ponytail: a small window if the Gmail history brings the deletion and the new version in different batches.
  Future<void> reconcile(String accountId) => transaction(() async {
    const inFolder =
        'message_id IN (SELECT m.message_id FROM messages m '
        'WHERE m.account_id = ?1 AND $_inFolder)';
    await customUpdate(
      'UPDATE drafts SET remote_known = 1 WHERE account_id = ?1 AND $inFolder',
      variables: [Variable(accountId)],
      updates: {drafts},
    );
    await customUpdate(
      'DELETE FROM drafts WHERE account_id = ?1 AND pending = 0 AND remote_known = 1 '
      'AND NOT $inFolder',
      variables: [Variable(accountId)],
      updates: {drafts},
      updateKind: UpdateKind.delete,
    );
  });
}
