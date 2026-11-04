import 'package:drift/drift.dart';

/// The offline queue (ADR 0008): per message, the state the user wants on the Provider, one column per attribute
/// (null: no intent), so intents on the same attribute merge and the last one wins. A row leaves once replayed.
// ponytail: no value-at-enqueue and no Conflitti yet: the replay applies blindly; add them with the
// first Azione that can clash (Archivia, Stella).
@DataClassName('IntentRow')
class Intents() extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();
  BoolColumn get isRead => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, messageId};
}
