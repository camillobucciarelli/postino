/// Thin platform services (keychain, clock, connectivity, links); real ones in core/data, fakes in tests.
abstract interface class SecureStore() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Legge il valore di `key`, null se manca.
  Future<String?> read(String key);

  /// Salva `value` sotto `key`.
  Future<void> write(String key, String value);
}

/// L'orologio, sostituibile nei test.
abstract interface class Clock() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// L'ora corrente.
  DateTime now();

  /// Fires every [period], for as long as it is listened to.
  Stream<void> every(Duration period);
}

/// Lo stato della rete.
abstract interface class Connectivity() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Se il dispositivo è online ora.
  bool get isOnline;

  /// The new state, each time it changes.
  Stream<bool> get onChanged;

  /// Whether the device is on Wi-Fi now; false when it cannot tell (ADR 0015: a large download asks first).
  Future<bool> isOnWifi();
}

/// Opens a link outside Postino: the system browser, or the mail client for `mailto:`.
abstract interface class LinkOpener() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Apre `url` fuori da Postino.
  Future<void> open(Uri url);
}

/// The Save As dialog: copies a file where the user picks.
abstract interface class FileSaver() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// False where the platform has no such dialog (Android, iOS).
  bool get available;

  /// Asks where to save the file at [path], suggesting [name], and copies it there; nothing if the user backs out.
  Future<void> save(String path, String name);
}

/// Keeps the outbox going after the user leaves the app (#36): iOS background task, Android WorkManager one-shot, nothing on desktop.
abstract interface class BackgroundSender() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Called when an outgoing message is queued: asks the platform for time or work to send it.
  Future<void> hold(String accountId);

  /// Called when the Account's outbox is empty again.
  Future<void> release(String accountId);
}
