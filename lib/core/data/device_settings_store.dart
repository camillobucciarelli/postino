import 'package:injectable/injectable.dart';

import '../domain/settings_repository.dart';
import 'postino_database.dart';

@LazySingleton(as: SettingsRepository)
class DeviceSettingsStore(final PostinoDatabase _db) implements SettingsRepository {
  static const _sidebar = 'sidebar_expanded';
  static const _listWidth = 'list_width';
  static const _launchAtLogin = 'launch_at_login';
  static const _notificationsAsked = 'notifications_asked';
  static const _settingsSyncAccount = 'settings_sync_account';

  @override
  Future<bool?> sidebarExpanded() => _bool(_sidebar);

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

  @override
  Future<bool?> launchAtLogin() => _bool(_launchAtLogin);

  @override
  Future<void> setLaunchAtLogin({required bool enabled}) =>
      _db.deviceSettingsDao.write(_launchAtLogin, enabled.toString());

  @override
  Future<bool> notificationsAsked() async => await _bool(_notificationsAsked) ?? false;

  @override
  Future<void> setNotificationsAsked() => _db.deviceSettingsDao.write(_notificationsAsked, 'true');

  @override
  Future<String?> settingsSyncAccount() => _db.deviceSettingsDao.read(_settingsSyncAccount);

  @override
  Stream<String?> watchSettingsSyncAccount() => _db.deviceSettingsDao.watch(_settingsSyncAccount);

  @override
  Future<void> setSettingsSyncAccount(String? accountId) =>
      _db.deviceSettingsDao.write(_settingsSyncAccount, accountId);

  Future<bool?> _bool(String key) async => switch (await _db.deviceSettingsDao.read(key)) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}
