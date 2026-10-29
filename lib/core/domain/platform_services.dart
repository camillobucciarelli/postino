/// Thin platform services (keychain, clock, connectivity); real ones in core/data, fakes in tests.
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
