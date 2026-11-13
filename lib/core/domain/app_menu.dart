/// The app's own menu: the «Posta» menu of the macOS menu bar (#251); nothing comes elsewhere.
abstract interface class AppMenu() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// «Aggiorna» (Cmd+R) chosen from the menu.
  Stream<void> get refresh;
}
