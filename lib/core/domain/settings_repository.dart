/// The Impostazioni del dispositivo (ADR 0004): what this device remembers between runs.
abstract interface class SettingsRepository {
  /// The manual choice of the sidebar: true extended, false icons only, null none (the window width decides).
  Future<bool?> sidebarExpanded();

  Future<void> setSidebarExpanded({required bool? expanded});

  /// The width in pixels the user chose for the list; null: none, the default applies. Not limited to the window.
  Future<double?> listWidth();

  Future<void> setListWidth(double width);
}
