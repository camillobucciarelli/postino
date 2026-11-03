import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<PostinoDatabase>
    with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  /// sendAfter of a row whose MIME is still being prepared: never due, "waiting" in the UI.
  // ponytail: a crash during preparation leaves the row until the user's Annulla; sweep stale ones if it matters.
  static const preparing = 1 << 52;

  /// Fills the MIME of the row of preparation [version] still being prepared and sets its real deadline; false when it is gone (cancelled).
  Future<bool> ready(
    String accountId,
    String messageId,
    int version,
    String raw,
    int sendAfter,
  ) async =>
      await (update(outbox)..where(
            (t) =>
                _row(t, accountId, messageId) &
                t.version.equals(version) &
                t.sendAfter.equals(preparing),
          ))
          .write(
            OutboxCompanion(raw: Value(raw), sendAfter: Value(sendAfter)),
          ) >
      0;

  /// Queues the message; the same Message-ID replaces the row (a second Invia after an Annulla).
  Future<void> enqueue(OutboxCompanion row) =>
      into(outbox).insert(row, mode: InsertMode.insertOrReplace);

  Future<OutboxRow?> byId(String accountId, String messageId) => (select(
    outbox,
  )..where((t) => _row(t, accountId, messageId))).getSingleOrNull();

  /// Annulla: removes the row unless a sender holds an unexpired claim on it (it is going now); true when removed.
  Future<bool> cancel(String accountId, String messageId, int nowMs) async =>
      await (delete(
            outbox,
          )..where((t) => _row(t, accountId, messageId) & _unclaimed(t, nowMs)))
          .go() >
      0;

  /// Removes the row of preparation [version] (a failed one); a newer row of the same Message-ID stays.
  Future<bool> drop(String accountId, String messageId, int version) async =>
      await (delete(outbox)..where(
            (t) => _row(t, accountId, messageId) & t.version.equals(version),
          ))
          .go() >
      0;

  /// Removes the row; true when there was one.
  Future<bool> remove(String accountId, String messageId) async =>
      await (delete(outbox)..where((t) => _row(t, accountId, messageId))).go() >
      0;

  /// The rows whose window ended by [nowMs] and not refused for good, oldest first.
  Future<List<OutboxRow>> due(String accountId, int nowMs) =>
      (select(outbox)
            ..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.sendAfter.isSmallerOrEqualValue(nowMs) &
                  t.failed.not(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.sendAfter)]))
          .get();

  /// True while the Account has any row still to send.
  Future<bool> any(String accountId) async =>
      (await (select(outbox)
                ..where((t) => t.accountId.equals(accountId) & t.failed.not())
                ..limit(1))
              .get())
          .isNotEmpty;

  /// Every row of the Account, newest first.
  Stream<List<OutboxRow>> watch(String accountId) =>
      (select(outbox)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.sendAfter)]))
          .watch();

  /// Takes the row for one sender until [untilMs], unless another holds an unexpired claim; true when taken.
  /// Bound to the version the sender read ([sendAfter]): a row cancelled and queued again (new sendAfter) is not it.
  /// One UPDATE, so two isolates on the same file never both win.
  Future<bool> claim(
    String accountId,
    String messageId,
    int sendAfter,
    int untilMs,
    int nowMs,
  ) async =>
      await (update(outbox)..where(
            (t) =>
                _row(t, accountId, messageId) &
                t.sendAfter.equals(sendAfter) &
                t.failed.not() &
                _unclaimed(t, nowMs),
          ))
          .write(OutboxCompanion(claimedUntil: Value(untilMs))) >
      0;

  /// Gives the row back after a send that failed but may be retried.
  Future<void> unclaim(String accountId, String messageId) =>
      (update(outbox)..where((t) => _row(t, accountId, messageId))).write(
        const OutboxCompanion(claimedUntil: Value(null)),
      );

  Future<void> markFailed(String accountId, String messageId) =>
      (update(outbox)..where((t) => _row(t, accountId, messageId))).write(
        const OutboxCompanion(failed: Value(true), claimedUntil: Value(null)),
      );

  static Expression<bool> _unclaimed(Outbox t, int nowMs) =>
      t.claimedUntil.isNull() | t.claimedUntil.isSmallerThanValue(nowMs);

  static Expression<bool> _row(Outbox t, String accountId, String messageId) =>
      t.accountId.equals(accountId) & t.messageId.equals(messageId);
}
