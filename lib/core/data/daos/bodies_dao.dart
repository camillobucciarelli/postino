import 'package:drift/drift.dart';

import '../../domain/message.dart';
import '../postino_database.dart';
import '../search_index.dart';
import '../tables/bodies_table.dart';

part 'bodies_dao.g.dart';

/// Downloaded message bodies. The `*In` methods add to a [Batch] of the caller's transaction (ADR 0008).
@DriftAccessor(tables: [Bodies])
class BodiesDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$BodiesDaoMixin {
  /// Drops the bodies of the Account's messages absent from the `snapshot_ids` TEMP table.
  void deleteNotInSnapshotIn(Batch b, String accountId) => b.deleteWhere(
    bodies,
    (t) => t.accountId.equals(accountId) & const CustomExpression('message_id NOT IN (SELECT id FROM snapshot_ids)'),
  );

  void deleteIn(Batch b, String accountId, String messageId) =>
      b.deleteWhere(bodies, (t) => t.accountId.equals(accountId) & t.messageId.equals(messageId));

  /// Each body goes to the search index too (#205), after its message: the caller adds the messages first.
  void upsertAllIn(Batch b, String accountId, Map<String, MessageBody> all) {
    b.insertAll(bodies, [
      for (final MapEntry(:key, :value) in all.entries) _companion(accountId, key, value),
    ], mode: InsertMode.insertOrReplace);
    for (final MapEntry(:key, :value) in all.entries) {
      b.customStatement(indexBodySql, [accountId, key, searchableText(value)]);
    }
  }

  Future<void> saveBody(String accountId, String messageId, MessageBody body) => transaction(() async {
    await into(bodies).insert(_companion(accountId, messageId, body), mode: InsertMode.insertOrReplace);
    await customStatement(indexBodySql, [accountId, messageId, searchableText(body)]);
  });

  BodiesCompanion _companion(String accountId, String messageId, MessageBody body) => BodiesCompanion.insert(
    accountId: accountId,
    messageId: messageId,
    body: body.content,
    kind: Value(body.kind),
    attachments: Value(body.attachments),
  );

  /// Removes the Account's message bodies (Rimozione di un Account, #174).
  Future<void> deleteByAccount(String accountId) => (delete(bodies)..where((t) => t.accountId.equals(accountId))).go();
}
