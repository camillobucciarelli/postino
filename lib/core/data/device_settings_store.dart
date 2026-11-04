import 'package:injectable/injectable.dart';

import '../domain/settings_repository.dart';
import 'postino_database.dart';

@LazySingleton(as: SettingsRepository)
class DeviceSettingsStore(this._db) implements SettingsRepository {
  final PostinoDatabase _db;

  static const _sidebar = 'sidebar_expanded';
  static const _listWidth = 'list_width';

  @override
  Future<bool?> sidebarExpanded() async => switch (await _db.deviceSettingsDao.read(_sidebar)) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  @override
  Future<void> setSidebarExpanded({required bool? expanded}) =>
      _db.deviceSettingsDao.write(_sidebar, expanded?.toString());

  @override
  Future<double?> listWidth() async {
    final v = await _db.deviceSettingsDao.read(_listWidth);
    return v == null ? null : double.tryParse(v);
  }

  @override
  Future<void> setListWidth(double width) => _db.deviceSettingsDao.write(_listWidth, width.toString());
}
