/// Avvio al login (#38): the OS's own registration of Postino, which stays the truth (the user can also change it
/// from the system's settings). Desktop only; the real one in core/data, a fake in tests.
abstract interface class LaunchAtLogin() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// False where the platform has no avvio al login for Postino (mobile, macOS before 13).
  bool get supported;

  /// Whether the OS starts Postino at login now.
  Future<bool> isEnabled();

  /// Registers (or removes) Postino as a login item; throws when the OS refuses.
  Future<void> setEnabled({required bool enabled});

  /// Whether the avvio al login started this run (#239): then the window stays hidden in the tray.
  Future<bool> launchedAtLogin();
}
