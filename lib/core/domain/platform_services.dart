/// Thin platform services (keychain, clock, connectivity); real ones in core/data, fakes in tests.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

abstract interface class Clock {
  DateTime now();
}

abstract interface class Connectivity {
  bool get isOnline;
  Stream<bool> get onChanged;
}
