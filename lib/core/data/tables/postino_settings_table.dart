import 'package:drift/drift.dart';

/// Impostazioni di Postino (ADR 0004): one JSON value per voce, the unit Drive will sync with last-write-wins
/// (v1.1). Local only in v1.
@DataClassName('PostinoSettingRow')
class PostinoSettings() extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
