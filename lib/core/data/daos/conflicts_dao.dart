import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/conflicts_table.dart';
import '../tables/intents_table.dart';

part 'conflicts_dao.g.dart';

/// The open Conflitti (ADR 0008) and their resolution.
@DriftAccessor(tables: [Conflicts, Intents])
class ConflictsDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$ConflictsDaoMixin {
  /// The open Conflitti, of every Account or only of [accountId].
  Stream<List<ConflictRow>> watch({String? accountId}) => (select(
    conflicts,
  )..where((t) => accountId == null ? const Constant(true) : t.accountId.equals(accountId))).watch();

  /// «Tieni la mia»: the Conflitto closes and its local value is queued again, forced on the Provider; a newer
  /// Azione queued over it stands instead. False when it was no longer open.
  Future<bool> keepMine(String accountId, String messageId, String attribute) => transaction(() async {
    final c = await _take(accountId, messageId, attribute);
    if (c == null) return false;
    await into(intents).insert(
      IntentsCompanion.insert(accountId: accountId, messageId: messageId, attribute: attribute, wanted: c.local),
      mode: InsertMode.insertOrIgnore,
    );
    return true;
  });

  /// «Tieni quella del Provider»: the Conflitto closes, the message takes the Provider's value here and nothing on
  /// the attribute stays queued. False when it was no longer open.
  Future<bool> keepProvider(String accountId, String messageId, String attribute) => transaction(() async {
    final c = await _take(accountId, messageId, attribute);
    if (c == null) return false;
    await (delete(intents)
          ..where((t) => t.accountId.equals(accountId) & t.messageId.equals(messageId) & t.attribute.equals(attribute)))
        .go();
    await attachedDatabase.attributesDao.write(accountId, messageId, attribute, c.provider);
    return true;
  });

  Future<ConflictRow?> _take(String accountId, String messageId, String attribute) async {
    Expression<bool> key($ConflictsTable t) =>
        t.accountId.equals(accountId) & t.messageId.equals(messageId) & t.attribute.equals(attribute);
    final c = await (select(conflicts)..where(key)).getSingleOrNull();
    if (c != null) await (delete(conflicts)..where(key)).go();
    return c;
  }
}
