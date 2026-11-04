/// What the tray's menu asks for.
enum TrayCommand() {
  /// Apri la finestra.
  open,

  /// Esci da Postino.
  quit,
}

/// Postino's icon in the tray (menu bar on macOS, notification area on Windows, StatusNotifierItem on Linux), #38.
abstract interface class SystemTray() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Puts the icon with its menu in the tray; throws when the system has no tray to put it in.
  Future<void> show({required String tooltip, required String openLabel, required String quitLabel});

  /// Removes the icon, before the process ends.
  Future<void> hide();

  /// The commands chosen from the icon and its menu.
  Stream<TrayCommand> get commands;
}
