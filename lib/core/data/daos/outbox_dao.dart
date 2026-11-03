import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<PostinoDatabase>
    with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  /// Queues the message; the same Message-ID replaces the row (a second Invia after an Annulla).
  Future<void> enqueue(OutboxCompanion row) =>
      into(outbox).insert(row, mode: InsertMode.insertOrReplace);

  Future<OutboxRow?> byId(String accountId, String messageId) => (select(
    outbox,
  )..where((t) => _row(t, accountId, messageId))).getSingleOrNull();

  /// Removes the row; true when there was one.
  Future<bool> remove(String accountId, String messageId) async =>
      await (delete(outbox)..where((t) => _row(t, accountId, messageId))).go() >
      0;

  /// The rows whose window ended by [nowMs], oldest first.
  Future<List<OutboxRow>> due(String accountId, int nowMs) =>
      (select(outbox)
            ..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.sendAfter.isSmallerOrEqualValue(nowMs),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.sendAfter)]))
          .get();

  /// True while the Account has any row queued.
  Future<bool> any(String accountId) async =>
      (await (select(outbox)
                ..where((t) => t.accountId.equals(accountId))
                ..limit(1))
              .get())
          .isNotEmpty;

  /// Every row of the Account, newest first.
  Stream<List<OutboxRow>> watch(String accountId) =>
      (select(outbox)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.sendAfter)]))
          .watch();

  Future<void> bumpAttempts(String accountId, String messageId) =>
      (update(outbox)..where((t) => _row(t, accountId, messageId))).write(
        OutboxCompanion.custom(attempts: outbox.attempts + const Constant(1)),
      );

  static Expression<bool> _row(Outbox t, String accountId, String messageId) =>
      t.accountId.equals(accountId) & t.messageId.equals(messageId);
}
