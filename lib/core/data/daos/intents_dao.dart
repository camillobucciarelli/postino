import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/intents_table.dart';

part 'intents_dao.g.dart';

@DriftAccessor(tables: [Intents])
class IntentsDao extends DatabaseAccessor<PostinoDatabase> with _$IntentsDaoMixin {
  IntentsDao(super.attachedDatabase);

  /// The Account's intents still to replay.
  Future<List<IntentRow>> pending(String accountId) =>
      (select(intents)..where((t) => t.accountId.equals(accountId))).get();

  /// The read intents of [messageIds] reached the Provider as [isRead]; one changed meanwhile stays.
  Future<void> readDone(String accountId, List<String> messageIds, {required bool isRead}) => (delete(
    intents,
  )..where((t) => t.accountId.equals(accountId) & t.messageId.isIn(messageIds) & t.isRead.equals(isRead))).go();
}
