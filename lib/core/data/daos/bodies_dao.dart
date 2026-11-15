import 'package:drift/drift.dart';

import '../../domain/message.dart';
import '../postino_database.dart';
import '../search_index.dart';
import '../tables/bodies_table.dart';

part 'bodies_dao.g.dart';

/// The downloaded body knows better than the sync whether a message has attachments (#206): the message takes the
/// body's answer, and keeps its own when the body does not know them (null).
const _setHasAttachments =
    'UPDATE messages SET has_attachments = json_array_length(b.attachments) > 0 FROM bodies b '
    'WHERE messages.account_id = ?1 AND messages.id = ?2 AND b.account_id = ?1 AND b.message_id = ?2 '
    'AND b.attachments IS NOT NULL';

/// Downloaded message bodies. The `*In` methods add to a [Batch] of the caller's transaction (ADR 0008).
@DriftAccessor(tables: [Bodies])
class BodiesDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$BodiesDaoMixin {
  /// Drops the bodies of the Account's messages absent from the `snapshot_ids` TEMP table.
  void deleteNotInSnapshotIn(Batch b, String accountId) => b.deleteWhere(
    bodies,
    (t) => t.accountId.equals(accountId) & const CustomExpression('message_id NOT IN (SELECT id FROM snapshot_ids)'),
  );

  /// The message takes the attachments its stored body knows (#206): a sync that only guesses does not undo them.
  void correctHasAttachmentsIn(Batch b, String accountId, String messageId) =>
      b.customStatement(_setHasAttachments, [accountId, messageId]);

  void deleteIn(Batch b, String accountId, String messageId) =>
      b.deleteWhere(bodies, (t) => t.accountId.equals(accountId) & t.messageId.equals(messageId));

  /// Each body goes to the search index too (#205), after its message: the caller adds the messages first.
  /// [texts]: the [searchableTextsOf] the bodies, made by the caller before its transaction (#221).
  void upsertAllIn(Batch b, String accountId, Map<String, MessageBody> all, Map<String, String> texts) {
    b.insertAll(bodies, [
      for (final MapEntry(:key, :value) in all.entries) _companion(accountId, key, value),
    ], mode: InsertMode.insertOrReplace);
    for (final key in all.keys) {
      b
        ..customStatement(indexBodySql, [accountId, key, texts[key]!])
        ..customStatement(_setHasAttachments, [accountId, key]);
    }
  }

  /// [text]: its [searchableText], when the caller made it before its own transaction (#221).
  Future<void> saveBody(String accountId, String messageId, MessageBody body, {String? text}) async {
    final indexed = text ?? (await searchableTexts([body])).single;
    return transaction(() async {
      await into(bodies).insert(_companion(accountId, messageId, body), mode: InsertMode.insertOrReplace);
      await customStatement(indexBodySql, [accountId, messageId, indexed]);
      await customStatement(_setHasAttachments, [accountId, messageId]);
    });
  }

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
