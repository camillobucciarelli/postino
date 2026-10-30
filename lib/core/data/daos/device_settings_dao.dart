import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/device_settings_table.dart';

part 'device_settings_dao.g.dart';

@DriftAccessor(tables: [DeviceSettings])
class DeviceSettingsDao extends DatabaseAccessor<PostinoDatabase>
    with _$DeviceSettingsDaoMixin {
  DeviceSettingsDao(super.attachedDatabase);

  Future<String?> read(String key) async => (await (select(
    deviceSettings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  /// A null [value] removes the setting.
  Future<void> write(String key, String? value) => value == null
      ? (delete(deviceSettings)..where((t) => t.key.equals(key))).go()
      : into(deviceSettings).insertOnConflictUpdate(
          DeviceSettingsCompanion.insert(key: key, value: value),
        );
}
