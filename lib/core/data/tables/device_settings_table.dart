import 'package:drift/drift.dart';

/// Impostazioni del dispositivo (ADR 0004): one text value per key, never synced.
@DataClassName('DeviceSettingRow')
class DeviceSettings() extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
