/// Thin platform services (keychain, clock, connectivity, links); real ones in core/data, fakes in tests.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class SecureStore() {
  /// Legge il valore di `key`, null se manca.
  Future<String?> read(String key);

  /// Salva `value` sotto `key`.
  Future<void> write(String key, String value);
}

/// L'orologio, sostituibile nei test.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class Clock() {
  /// L'ora corrente.
  DateTime now();

  /// Fires every [period], for as long as it is listened to.
  Stream<void> every(Duration period);
}

/// Lo stato della rete.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class Connectivity() {
  /// Se il dispositivo è online ora.
  bool get isOnline;

  /// The new state, each time it changes.
  Stream<bool> get onChanged;
}

/// Opens a link outside Postino: the system browser, or the mail client for `mailto:`.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class LinkOpener() {
  /// Apre `url` fuori da Postino.
  Future<void> open(Uri url);
}

/// The Save As dialog: copies a file where the user picks.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class FileSaver() {
  /// False where the platform has no such dialog (Android, iOS).
  bool get available;

  /// Asks where to save the file at [path], suggesting [name], and copies it there; nothing if the user backs out.
  Future<void> save(String path, String name);
}

/// Keeps the outbox going after the user leaves the app (#36): iOS background task, Android WorkManager one-shot, nothing on desktop.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class BackgroundSender() {
  /// Called when an outgoing message is queued: asks the platform for time or work to send it.
  Future<void> hold(String accountId);

  /// Called when the Account's outbox is empty again.
  Future<void> release(String accountId);
}
