/// The Impostazioni del dispositivo (ADR 0004): what this device remembers between runs.
abstract interface class SettingsRepository {
  /// The manual choice of the sidebar: true extended, false icons only, null none (the window width decides).
  Future<bool?> sidebarExpanded();

  Future<void> setSidebarExpanded(bool? expanded);
}
