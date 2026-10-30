import 'package:injectable/injectable.dart';

import '../domain/settings_repository.dart';
import 'postino_database.dart';

@LazySingleton(as: SettingsRepository)
class DeviceSettingsStore implements SettingsRepository {
  DeviceSettingsStore(this._db);
  final PostinoDatabase _db;

  static const _sidebar = 'sidebar_expanded';

  @override
  Future<bool?> sidebarExpanded() async =>
      switch (await _db.deviceSettingsDao.read(_sidebar)) {
        'true' => true,
        'false' => false,
        _ => null,
      };

  @override
  Future<void> setSidebarExpanded(bool? expanded) =>
      _db.deviceSettingsDao.write(_sidebar, expanded?.toString());
}
