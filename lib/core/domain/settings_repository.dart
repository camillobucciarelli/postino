import 'notification_action.dart';

/// The Impostazioni del dispositivo (ADR 0004): what this device remembers between runs.
abstract interface class SettingsRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The manual choice of the sidebar: true extended, false icons only, null none (the window width decides).
  Future<bool?> sidebarExpanded();

  /// Ricorda la scelta della sidebar; null cancella la scelta manuale.
  Future<void> setSidebarExpanded({required bool? expanded});

  /// The ids of the Accounts closed in the drawer on this device (#311); the others are open.
  Future<Set<String>> collapsedAccounts();

  /// Ricorda quali Account sono chiusi nel drawer.
  Future<void> setCollapsedAccounts(Set<String> accountIds);

  /// The width in pixels the user chose for the list; null: none, the default applies. Not limited to the window.
  Future<double?> listWidth();

  /// Ricorda la larghezza scelta per l'elenco.
  Future<void> setListWidth(double width);

  /// The last avvio al login chosen on this device (#38); null before the first run applied the default.
  Future<bool?> launchAtLogin();

  /// Ricorda la scelta dell'avvio al login.
  Future<void> setLaunchAtLogin({required bool enabled});

  /// The Notifiche immediate chosen on this device (#214); null before any choice (off).
  Future<bool?> immediateNotifications();

  /// Ricorda la scelta delle Notifiche immediate.
  Future<void> setImmediateNotifications({required bool enabled});

  /// Whether this device already explained the notifications and offered the OS's permission (#39).
  Future<bool> notificationsAsked();

  /// Ricorda che la spiegazione delle notifiche è stata mostrata.
  Future<void> setNotificationsAsked();

  /// The id of the Account whose Drive holds the Impostazioni di Postino (ADR 0016); null: no sync.
  Future<String?> settingsSyncAccount();

  /// The id of the Account whose Drive holds the Impostazioni di Postino (ADR 0016), now and after each change;
  /// null: no sync.
  Stream<String?> watchSettingsSyncAccount();

  /// Sceglie l'Account su cui sincronizzare le Impostazioni di Postino; null spegne la sincronizzazione.
  Future<void> setSettingsSyncAccount(String? accountId);

  /// The Azioni delle notifiche (#211); [notificationActionsDefault] until chosen.
  Future<NotificationActions> notificationActions();

  /// Ricorda le Azioni delle notifiche; null in un posto è «Nessuna».
  Future<void> setNotificationActions(NotificationActions actions);
}
