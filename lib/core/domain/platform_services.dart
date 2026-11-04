/// Thin platform services (keychain, clock, connectivity, links); real ones in core/data, fakes in tests.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

abstract interface class Clock {
  DateTime now();

  /// Fires every [period], for as long as it is listened to.
  Stream<void> every(Duration period);
}

abstract interface class Connectivity {
  bool get isOnline;

  /// The new state, each time it changes.
  Stream<bool> get onChanged;
}

/// Opens a link outside Postino: the system browser, or the mail client for `mailto:`.
abstract interface class LinkOpener {
  Future<void> open(Uri url);
}

/// The Save As dialog: copies a file where the user picks.
abstract interface class FileSaver {
  /// False where the platform has no such dialog (Android, iOS).
  bool get available;

  /// Asks where to save the file at [path], suggesting [name], and copies it there; nothing if the user backs out.
  Future<void> save(String path, String name);
}

/// Keeps the outbox going after the user leaves the app (#36): iOS background task, Android WorkManager one-shot, nothing on desktop.
abstract interface class BackgroundSender {
  /// Called when an outgoing message is queued: asks the platform for time or work to send it.
  Future<void> hold(String accountId);

  /// Called when the Account's outbox is empty again.
  Future<void> release(String accountId);
}
