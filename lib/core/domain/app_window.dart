/// Postino's window on desktop (#38); the real one in core/data, a fake in tests.
abstract interface class AppWindow() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// From now on closing the window (its button, Cmd/Ctrl+W) leaves it open and fires here instead.
  Stream<void> interceptClose();

  /// Shows the window, in front and focused.
  Future<void> show();

  /// Hides the window; the process keeps running.
  Future<void> hide();

  /// Ends the process.
  Future<void> quit();
}
