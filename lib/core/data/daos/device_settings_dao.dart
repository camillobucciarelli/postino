import 'dart:math';

import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/device_settings_table.dart';

part 'device_settings_dao.g.dart';

@DriftAccessor(tables: [DeviceSettings])
class DeviceSettingsDao(super.attachedDatabase)
    extends DatabaseAccessor<PostinoDatabase>
    with _$DeviceSettingsDaoMixin {
  static const _deviceId = 'device_id';

  Future<String?> read(String key) async => (await _select(key).getSingleOrNull())?.value;

  /// The value of [key] now, then each time it changes; null while missing.
  Stream<String?> watch(String key) => _select(key).map((r) => r.value).watchSingleOrNull();

  /// A null [value] removes the setting.
  Future<void> write(String key, String? value) => value == null
      ? (delete(deviceSettings)..where((t) => t.key.equals(key))).go()
      : into(deviceSettings).insertOnConflictUpdate(DeviceSettingsCompanion.insert(key: key, value: value));

  /// This device's id for last-write-wins (ADR 0016): random, made on first use, then stable.
  Future<String> deviceId() => transaction(() async {
    if (await read(_deviceId) case final id?) return id;
    final random = Random.secure();
    final id = [for (var i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
    await write(_deviceId, id);
    return id;
  });

  SimpleSelectStatement<$DeviceSettingsTable, DeviceSettingRow> _select(String key) =>
      select(deviceSettings)..where((t) => t.key.equals(key));
}
