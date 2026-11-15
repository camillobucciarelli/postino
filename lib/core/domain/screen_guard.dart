/// Keeps a secret on screen (the codice di abbinamento, ADR 0019) out of screenshots and recordings where the platform
/// allows it: `FLAG_SECURE` on Android, `WDA_EXCLUDEFROMCAPTURE` on Windows, `NSWindow.sharingType = .none` on macOS
/// (legacy, not to be relied on). On iOS screenshots cannot be stopped: it tells when the screen is recorded or
/// mirrored, so the secret hides. On Linux it does nothing.
abstract interface class ScreenGuard() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Turns the protection on or off; true when the screen is being captured now (iOS only).
  Future<bool> protect({required bool on});

  /// Whether the screen is being captured, at every change (iOS only).
  Stream<bool> watchCaptured();
}
