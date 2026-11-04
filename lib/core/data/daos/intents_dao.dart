import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/intents_table.dart';
import '../tables/label_intents_table.dart';
import '../tables/message_labels_table.dart';

part 'intents_dao.g.dart';

@DriftAccessor(tables: [Intents, LabelIntents, MessageLabels])
class IntentsDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$IntentsDaoMixin {
  /// The Account's intents still to replay.
  Future<List<IntentRow>> pending(String accountId) =>
      (select(intents)..where((t) => t.accountId.equals(accountId))).get();

  /// The read intents of [messageIds] reached the Provider as [isRead]; one changed meanwhile stays.
  Future<void> readDone(String accountId, List<String> messageIds, {required bool isRead}) => (delete(
    intents,
  )..where((t) => t.accountId.equals(accountId) & t.messageId.isIn(messageIds) & t.isRead.equals(isRead))).go();

  /// The Account's Etichette intents still to replay.
  Future<List<LabelIntentRow>> pendingLabels(String accountId) =>
      (select(labelIntents)..where((t) => t.accountId.equals(accountId))).get();

  /// Puts the Etichetta [labelId] on message [messageId] here at once ([add] false: takes it off)
  /// and queues the same intent for the Provider, replacing any earlier one on the pair.
  Future<void> queueLabel(String accountId, String messageId, String labelId, {required bool add}) => transaction(
    () async {
      final row = MessageLabelsCompanion.insert(accountId: accountId, messageId: messageId, labelId: labelId);
      if (add) {
        await into(messageLabels).insert(row, mode: InsertMode.insertOrIgnore);
      } else {
        await (delete(messageLabels)
              ..where((t) => t.accountId.equals(accountId) & t.messageId.equals(messageId) & t.labelId.equals(labelId)))
            .go();
      }
      await into(labelIntents).insertOnConflictUpdate(
        LabelIntentsCompanion.insert(accountId: accountId, messageId: messageId, labelId: labelId, added: add),
      );
    },
  );

  /// The intent reached the Provider as [added]; one changed meanwhile stays.
  Future<void> labelDone(String accountId, String messageId, String labelId, {required bool added}) =>
      (delete(labelIntents)..where(
            (t) =>
                t.accountId.equals(accountId) &
                t.messageId.equals(messageId) &
                t.labelId.equals(labelId) &
                t.added.equals(added),
          ))
          .go();
}
