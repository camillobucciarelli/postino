import '../domain/platform_services.dart';

/// Reads [name] from a device-only [keychain] (#263), null if it has none; a keychain that cannot be read throws.
///
/// An older version saved it under a migratable attribute, which a device-only write replaces (on iOS by deleting the
/// item and adding it again). So once per key it is copied first, the copy checked, then rewritten, checked, and the
/// copy dropped. A step that fails leaves the key (or its copy) readable and is tried again at the next start: the key
/// lost is the local database lost.
Future<String?> readDeviceOnly(SecureStore keychain, String name) async {
  final copy = '$name.migrating';
  final done = '$name.device_only';
  final current = await keychain.read(name);
  if (current != null && await keychain.read(done) != null) return current;
  final value = current ?? await keychain.read(copy);
  if (value == null) return null;
  try {
    await _writeChecked(keychain, copy, value);
    await _writeChecked(keychain, name, value);
    await keychain.write(done, '1');
    await keychain.delete(copy);
    // ponytail: silent, the error log's keys derive from this one; the next start tries again.
  } on Object catch (_) {}
  return value;
}

Future<void> _writeChecked(SecureStore keychain, String key, String value) async {
  await keychain.write(key, value);
  if (await keychain.read(key) != value) throw StateError('$key: read back differs');
}
