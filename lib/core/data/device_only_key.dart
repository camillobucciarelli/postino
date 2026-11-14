import '../domain/platform_services.dart';

/// The name of the device-only keychain binding (#263), for the modules that hold the database key.
const deviceOnlyKeychainName = 'deviceOnlyKeychain';

/// Reads [name] from a device-only [keychain] (#263), null if it has none; a keychain that cannot be read throws.
///
/// An older version saved it under a migratable attribute, which a device-only write replaces (on iOS by deleting the
/// item and adding it again). So once per key it is copied first and the copy checked, then the key is rewritten and
/// checked. The copy stays: while the key is being rewritten, or after a rewrite that deleted it and failed to add it
/// back, another isolate or the next start reads the copy, which is never rewritten itself. A step that fails is tried
/// again at the next start: the key lost is the local database lost.
Future<String?> readDeviceOnly(SecureStore keychain, String name) async {
  final current = await keychain.read(name);
  if (current != null && await keychain.read(_done(name)) != null) return current;
  final value = current ?? await keychain.read(_copy(name));
  if (value == null) return null;
  try {
    if (current != null) await _writeChecked(keychain, _copy(name), value);
    await _writeChecked(keychain, name, value);
    await keychain.write(_done(name), '1');
    // ponytail: silent, the error log's keys derive from this one; the next start tries again.
  } on Object catch (_) {}
  return value;
}

/// Saves a new [value] under [name], already device only: nothing to migrate.
Future<void> writeDeviceOnly(SecureStore keychain, String name, String value) async {
  await keychain.write(name, value);
  await keychain.write(_done(name), '1');
}

String _copy(String name) => '$name.copy';
String _done(String name) => '$name.device_only';

/// The read back checks the value only: the attribute is the store's, set by the write.
Future<void> _writeChecked(SecureStore keychain, String key, String value) async {
  await keychain.write(key, value);
  if (await keychain.read(key) != value) throw StateError('$key: read back differs');
}
