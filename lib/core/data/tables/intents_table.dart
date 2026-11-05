import 'package:drift/drift.dart';

/// The offline queue of the Azioni (ADR 0008, v18): per message and attribute, the value the user wants on the
/// Provider and the one the message had here when the first Azione was queued. Azioni on the same attribute merge:
/// the last [wanted] stays, with the first [expected]. A voce leaves once replayed or turned into a Conflitto.
/// Values are encoded by `action_codec.dart`.
@DataClassName('IntentRow')
class Intents() extends Table {
  TextColumn get accountId => text()();

  /// Provider-side id of the message.
  TextColumn get messageId => text()();

  /// `read`, `starred`, `placement` or `label:<id>` (`MailAction.attribute`).
  TextColumn get attribute => text()();
  TextColumn get wanted => text()();

  /// Null: the replay forces the write («tieni la mia» of a Conflitto).
  TextColumn get expected => text().nullable()();

  /// Milliseconds since epoch: the voce is «trattenuta» (its Annulla is still offered) and waits until then.
  IntColumn get heldUntil => integer().nullable()();

  /// What [wanted] was before the held Azione merged into this voce: its Annulla puts it back.
  TextColumn get previous => text().nullable()();

  /// The Provider's value the last sync brought while the voce waited (null: none since the enqueue). Taking the
  /// voce back (Annulla, a refusal) shows it instead of the stale [expected]; the replay still expects [expected],
  /// so a change elsewhere is a Conflitto (ADR 0008).
  TextColumn get synced => text().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, messageId, attribute};
}
