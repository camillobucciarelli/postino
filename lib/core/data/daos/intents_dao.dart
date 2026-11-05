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

  /// Puts the Etichetta [labelId] on [messageIds] here at once ([add] false: takes it off) and queues the same
  /// intents for the Provider, replacing any earlier one on each pair: one transaction, so the messages of a
  /// Conversazione show it all or none, and a later batch never interleaves with this one.
  Future<void> queueLabels(String accountId, Iterable<String> messageIds, String labelId, {required bool add}) =>
      transaction(() async {
        for (final messageId in messageIds) {
          await _setLocal(accountId, messageId, labelId, add: add);
          await into(labelIntents).insertOnConflictUpdate(
            LabelIntentsCompanion.insert(accountId: accountId, messageId: messageId, labelId: labelId, added: add),
          );
        }
      });

  /// The intent reached the Provider as [added]; one changed meanwhile stays.
  Future<int> labelDone(String accountId, String messageId, String labelId, {required bool added}) =>
      (delete(labelIntents)..where(
            (t) =>
                t.accountId.equals(accountId) &
                t.messageId.equals(messageId) &
                t.labelId.equals(labelId) &
                t.added.equals(added),
          ))
          .go();

  /// The Provider refused the intent [added]: it leaves the queue and the message gets back its Etichetta
  /// (or loses it) here. One changed meanwhile stays, with its local change.
  Future<void> labelRejected(String accountId, String messageId, String labelId, {required bool added}) =>
      transaction(() async {
        if (await labelDone(accountId, messageId, labelId, added: added) == 0) return;
        // Put back only on a message still here: one removed meanwhile gets no orphan label.
        if (!added && await _messageMissing(accountId, messageId)) return;
        await _setLocal(accountId, messageId, labelId, add: !added);
      });

  Future<bool> _messageMissing(String accountId, String messageId) async =>
      await customSelect(
        'SELECT 1 FROM messages WHERE account_id = ?1 AND id = ?2',
        variables: [Variable(accountId), Variable(messageId)],
      ).getSingleOrNull() ==
      null;

  Future<void> _setLocal(String accountId, String messageId, String labelId, {required bool add}) async {
    if (add) {
      await into(messageLabels).insert(
        MessageLabelsCompanion.insert(accountId: accountId, messageId: messageId, labelId: labelId),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (delete(
        messageLabels,
      )..where((t) => t.accountId.equals(accountId) & t.messageId.equals(messageId) & t.labelId.equals(labelId))).go();
    }
  }
}
