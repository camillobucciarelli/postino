import '../domain/platform_services.dart';

/// The name of the device-only keychain binding (#263), for the modules that hold the database key.
const deviceOnlyKeychainName = 'deviceOnlyKeychain';

/// Reads [name] from a device-only [keychain] (#263), null if it has none; a keychain that cannot be read throws.
///
/// An older version saved it under a migratable attribute, which a device-only write replaces (on iOS by deleting the
/// item and adding it again). So once per key it is copied first, the copy read back and marked checked, then the key
/// is rewritten and read back. A checked copy is never written again and is the value from then on: a rewrite that
/// deleted the key, or saved something else, is redone from it at the next start, and another isolate reading
/// meanwhile reads it. An unchecked copy is never trusted: the key was not rewritten yet, so it is copied again. The
/// migration is marked done only once the key reads back as the copy. The key lost is the local database lost.
Future<String?> readDeviceOnly(SecureStore keychain, String name) async {
  final current = await keychain.read(name);
  if (current != null && await keychain.read(_done(name)) != null) return current;
  final copy = await keychain.read(_copy(name));
  final checked = copy != null && await keychain.read(_checked(name)) != null;
  final value = checked ? copy : current ?? copy;
  if (value == null) return null;
  try {
    if (!checked) {
      await _writeChecked(keychain, _copy(name), value);
      await keychain.write(_checked(name), '1');
    }
    await _writeChecked(keychain, name, value);
    await keychain.write(_done(name), '1');
    // ponytail: silent, the error log's keys derive from this one; the next start tries again.
  } on Object catch (_) {}
  return value;
}

/// Saves a new [value] under [name], already device only: nothing to migrate. A read back that differs throws.
Future<void> writeDeviceOnly(SecureStore keychain, String name, String value) async {
  await _writeChecked(keychain, name, value);
  await keychain.write(_done(name), '1');
}

String _copy(String name) => '$name.copy';
String _checked(String name) => '$name.copied';
String _done(String name) => '$name.device_only';

/// The read back checks the value only: the attribute is the store's, set by the write.
Future<void> _writeChecked(SecureStore keychain, String key, String value) async {
  await keychain.write(key, value);
  if (await keychain.read(key) != value) throw StateError('$key: read back differs');
}
