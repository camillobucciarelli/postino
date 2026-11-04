/// The Impostazioni del dispositivo (ADR 0004): what this device remembers between runs.
abstract interface class SettingsRepository {
  /// The manual choice of the sidebar: true extended, false icons only, null none (the window width decides).
  Future<bool?> sidebarExpanded();

  /// Ricorda la scelta della sidebar; null cancella la scelta manuale.
  Future<void> setSidebarExpanded({required bool? expanded});

  /// The width in pixels the user chose for the list; null: none, the default applies. Not limited to the window.
  Future<double?> listWidth();

  /// Ricorda la larghezza scelta per l'elenco.
  Future<void> setListWidth(double width);
}
