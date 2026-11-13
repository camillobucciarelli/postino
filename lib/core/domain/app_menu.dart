/// The app's own menu: the «Posta» menu of the macOS menu bar (#251); nothing comes elsewhere.
abstract interface class AppMenu() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// «Aggiorna» clicked in the menu; its Cmd+R goes through the Posta shortcuts.
  Stream<void> get refresh;
}
