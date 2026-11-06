import 'package:drift/drift.dart';

/// The open Conflitti (ADR 0008, v18): a queued Azione that met its attribute changed elsewhere. While one is open
/// the message keeps the [local] value here; values are encoded by `action_codec.dart`.
@DataClassName('ConflictRow')
class Conflicts() extends Table {
  TextColumn get accountId => text()();

  /// Provider-side id of the message.
  TextColumn get messageId => text()();
  TextColumn get attribute => text()();
  TextColumn get local => text()();
  TextColumn get provider => text()();

  @override
  Set<Column> get primaryKey => {accountId, messageId, attribute};
}
