/// Aggiornamenti di Postino (#122): the platform's updater, Sparkle on macOS. It shows its own window, which also
/// says when there is nothing new. The real one in core/data, a fake in tests.
abstract interface class AppUpdater() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// False where Postino does not update itself (everywhere but macOS for now).
  bool get supported;

  /// Looks for a new version now, with the updater's own window.
  Future<void> checkForUpdates();
}
