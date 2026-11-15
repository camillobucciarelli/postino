import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../domain/notification_action.dart';
import '../domain/settings_repository.dart';
import 'postino_database.dart';

@LazySingleton(as: SettingsRepository)
class DeviceSettingsStore(final PostinoDatabase _db) implements SettingsRepository {
  static const _sidebar = 'sidebar_expanded';
  static const _collapsedAccounts = 'drawer_collapsed_accounts';
  static const _listWidth = 'list_width';
  static const _launchAtLogin = 'launch_at_login';
  static const _immediateNotifications = 'immediate_notifications';
  static const _notificationsAsked = 'notifications_asked';
  static const _settingsSyncAccount = 'settings_sync_account';
  static const _firstAction = 'notification_action_first';
  static const _secondAction = 'notification_action_second';
  static const _none = 'none';

  @override
  Future<bool?> sidebarExpanded() => _bool(_sidebar);

  @override
  Future<void> setSidebarExpanded({required bool? expanded}) =>
      _db.deviceSettingsDao.write(_sidebar, expanded?.toString());

  @override
  Future<Set<String>> collapsedAccounts() async {
    final v = await _db.deviceSettingsDao.read(_collapsedAccounts);
    try {
      return v == null ? const {} : {...(jsonDecode(v) as List).cast<String>()};
    } on Object {
      // A value that is not a list of ids: every Account open, never a drawer without Accounts.
      return const {};
    }
  }

  @override
  Future<void> setCollapsedAccounts(Set<String> accountIds) =>
      _db.deviceSettingsDao.write(_collapsedAccounts, jsonEncode(accountIds.toList()));

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
  Future<bool?> immediateNotifications() => _bool(_immediateNotifications);

  @override
  Future<void> setImmediateNotifications({required bool enabled}) =>
      _db.deviceSettingsDao.write(_immediateNotifications, enabled.toString());

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

  @override
  Future<NotificationActions> notificationActions() async => (
    first: await _action(_firstAction, notificationActionsDefault.first),
    second: await _action(_secondAction, notificationActionsDefault.second),
  );

  @override
  Future<void> setNotificationActions(NotificationActions actions) async {
    await _db.deviceSettingsDao.write(_firstAction, actions.first?.name ?? _none);
    await _db.deviceSettingsDao.write(_secondAction, actions.second?.name ?? _none);
  }

  /// The Azione kept at [key]: [fallback] while missing or unknown, null for «Nessuna».
  Future<NotificationAction?> _action(String key, NotificationAction fallback) async {
    final raw = await _db.deviceSettingsDao.read(key);
    if (raw == _none) return null;
    return NotificationAction.values.asNameMap()[raw] ?? fallback;
  }

  Future<bool?> _bool(String key) async => switch (await _db.deviceSettingsDao.read(key)) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}
