import 'package:drift/drift.dart';

import '../../domain/message.dart';
import '../postino_database.dart';
import '../tables/bodies_table.dart';

part 'bodies_dao.g.dart';

/// Downloaded message bodies. The `*In` methods add to a [Batch] of the caller's transaction (ADR 0008).
@DriftAccessor(tables: [Bodies])
class BodiesDao extends DatabaseAccessor<PostinoDatabase>
    with _$BodiesDaoMixin {
  BodiesDao(super.attachedDatabase);

  /// Drops the bodies of the Account's messages absent from the `snapshot_ids` TEMP table.
  void deleteNotInSnapshotIn(Batch b, String accountId) => b.deleteWhere(
    bodies,
    (t) =>
        t.accountId.equals(accountId) &
        const CustomExpression(
          'message_id NOT IN (SELECT id FROM snapshot_ids)',
        ),
  );

  void deleteIn(Batch b, String accountId, String messageId) => b.deleteWhere(
    bodies,
    (t) => t.accountId.equals(accountId) & t.messageId.equals(messageId),
  );

  void upsertAllIn(Batch b, String accountId, Map<String, MessageBody> all) =>
      b.insertAll(bodies, [
        for (final MapEntry(:key, :value) in all.entries)
          _companion(accountId, key, value),
      ], mode: InsertMode.insertOrReplace);

  Future<void> saveBody(String accountId, String messageId, MessageBody body) =>
      into(bodies).insert(
        _companion(accountId, messageId, body),
        mode: InsertMode.insertOrReplace,
      );

  BodiesCompanion _companion(
    String accountId,
    String messageId,
    MessageBody body,
  ) => BodiesCompanion.insert(
    accountId: accountId,
    messageId: messageId,
    body: body.content,
    kind: Value(body.kind),
    attachments: Value(body.attachments),
  );
}
