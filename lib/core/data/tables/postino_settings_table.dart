import 'package:drift/drift.dart';

/// Impostazioni di Postino (ADR 0004, 0016): one JSON value per voce, the unit of last-write-wins.
/// A removed voce stays as a tombstone, so the removal reaches the other devices.
@DataClassName('PostinoSettingRow')
class PostinoSettings() extends Table {
  TextColumn get key => text()();

  /// Null for a tombstone.
  TextColumn get value => text().nullable()();

  /// When the voce was written, in milliseconds UTC since the epoch.
  IntColumn get updatedAt => integer()();

  /// The device that wrote it: it decides a tie on [updatedAt].
  TextColumn get deviceId => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Written here and not yet in the synced file.
  BoolColumn get dirty => boolean()();

  @override
  Set<Column> get primaryKey => {key};
}
