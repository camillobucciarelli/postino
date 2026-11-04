import 'package:drift/drift.dart';

/// The Etichette part of the offline queue (ADR 0008): per message and Etichetta, whether the user wants it on
/// the Provider ([added]) or off; a new intent on the same pair replaces the old one, so the last one wins.
/// A row leaves once replayed.
// ponytail: no value-at-enqueue: an Etichetta is on a message or not, so the Provider holds either the value it had
// at enqueue or the wanted one, and the replay never meets a Conflitto. Store it if a non-boolean attribute joins.
@DataClassName('LabelIntentRow')
class LabelIntents() extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();
  TextColumn get labelId => text()();
  BoolColumn get added => boolean()();

  @override
  Set<Column> get primaryKey => {accountId, messageId, labelId};
}
