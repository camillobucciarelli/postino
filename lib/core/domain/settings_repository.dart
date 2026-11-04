/// The Impostazioni del dispositivo (ADR 0004): what this device remembers between runs.
abstract interface class SettingsRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The manual choice of the sidebar: true extended, false icons only, null none (the window width decides).
  Future<bool?> sidebarExpanded();

  /// Ricorda la scelta della sidebar; null cancella la scelta manuale.
  Future<void> setSidebarExpanded({required bool? expanded});

  /// The width in pixels the user chose for the list; null: none, the default applies. Not limited to the window.
  Future<double?> listWidth();

  /// Ricorda la larghezza scelta per l'elenco.
  Future<void> setListWidth(double width);

  /// The last avvio al login chosen on this device (#38); null before the first run applied the default.
  Future<bool?> launchAtLogin();

  /// Ricorda la scelta dell'avvio al login.
  Future<void> setLaunchAtLogin({required bool enabled});
}
