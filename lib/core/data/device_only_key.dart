import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/platform_services.dart';

/// The name of the device-only keychain binding (#263), for the modules that hold the database key.
const deviceOnlyKeychainName = 'deviceOnlyKeychain';

/// The device-only keychain of a macOS release (#270): the Data Protection keychain [to], the only one on macOS that
/// keeps an item on this Mac, while older versions saved the key in the legacy login keychain [from]. Reads, writes
/// and deletes go to [to]; [readDeviceOnly] moves the key from [from] first.
class MovingKeychain(final SecureStore to, final SecureStore from) implements SecureStore {
  @override
  Future<String?> read(String key) => to.read(key);

  @override
  Future<void> write(String key, String value) => to.write(key, value);

  @override
  Future<void> delete(String key) => to.delete(key);
}

/// Reads [name] from a device-only [keychain] (#263), null if it has none; a keychain that cannot be read throws, and
/// so does a key moved out of the legacy keychain and then not found (#270): never taken for none, which means a new
/// key and the database wiped.
///
/// An older version saved it under a migratable attribute, which a device-only write replaces (on iOS by deleting the
/// item and adding it again). So once per key it is copied first, the copy read back and marked checked, then the key
/// is rewritten and read back. A checked copy is never written again and is the value from then on: a rewrite that
/// deleted the key, or saved something else, is redone from it at the next start, and another isolate reading
/// meanwhile reads it. An unchecked copy never wins over the key, which was not rewritten yet, and is copied again from
/// it; with no key left it is the only value, better than a new key that wipes the database, and is only marked
/// checked. The migration is marked done only once the key reads back as the copy, and a key restored from the copy
/// drops an earlier mark first. The key lost is the local database lost.
Future<String?> readDeviceOnly(SecureStore keychain, String name) async {
  var legacy = keychain;
  if (keychain case MovingKeychain(:final to, :final from)) {
    if (await _move(from, to, name) case final value?) return value;
    legacy = from;
  }
  if (await _readMigrating(keychain, name) case final value?) return value;
  // In the Data Protection keychain, which a Debug build cannot read, or lost there.
  if (await legacy.read(_movedMark(name)) != null) throw StateError('$name: moved to the Data Protection keychain');
  return null;
}

/// Saves a new [value] under [name], already device only: nothing to migrate. A read back that differs throws.
/// On a macOS release the legacy keychain is marked moved too, after the key: a Debug build on the same Mac, which
/// shares the database but cannot read the key, then fails instead of wiping it (#270).
Future<void> writeDeviceOnly(SecureStore keychain, String name, String value) async {
  await _writeChecked(keychain, name, value);
  await keychain.write(_deviceOnlyMark(name), '1');
  if (keychain case MovingKeychain(:final from)) await from.write(_movedMark(name), '1');
}

/// The mark of a new [name] whose database is still to be wiped (#263): it moves with the key (#270).
String freshMark(String name) => '$name.fresh';

/// The value of the [freshMark] of [key]: the mark wipes only the database of that key, not one a later key made
/// after a downgrade (#270). Earlier versions wrote `1`, for the key they saved next.
String freshOf(String key) => sha256.convert(utf8.encode('fresh:$key')).toString();

Future<String?> _readMigrating(SecureStore keychain, String name) async {
  final current = await keychain.read(name);
  if (current != null && await keychain.read(_deviceOnlyMark(name)) != null) return current;
  final copy = await keychain.read(_copy(name));
  final checked = copy != null && await keychain.read(_copiedMark(name)) != null;
  final value = checked ? copy : current ?? copy;
  if (value == null) return null;
  try {
    if (current == null) {
      // Restored from the copy: until the key reads back right it is not migrated, whatever an earlier start marked.
      await keychain.delete(_deviceOnlyMark(name));
    }
    if (!checked) {
      // With no key the copy is the only value left: never rewritten, a failed write would lose it.
      if (current != null) await _writeChecked(keychain, _copy(name), value);
      await keychain.write(_copiedMark(name), '1');
    }
    await _writeChecked(keychain, name, value);
    await keychain.write(_deviceOnlyMark(name), '1');
    // ponytail: silent, the error log's keys derive from this one; the next start tries again.
  } on Object catch (_) {}
  return value;
}

/// Moves [name] from the legacy keychain [from] to [to] (#270), null if [from] has none. [from] keeps it until [to]
/// holds it, read back and marked, so a step that fails leaves it there: this start goes on with it, the next moves it
/// again. While [from] has a key it wins over [to]'s: only an older version, after a downgrade, writes there.
/// Only the moved mark is left in [from].
Future<String?> _move(SecureStore from, SecureStore to, String name) async {
  final value = await _readMigrating(from, name);
  if (value == null) return null;
  if (await from.read(freshMark(name)) case final fresh?) {
    // A new key whose database is still to be wiped: the mark moves before the key, as for a new one, and leaves
    // [from] before this start wipes, or a later start would carry it again and wipe the new database. Either step
    // failing fails the start, to be tried again. A mark of another key is stale: dropped.
    if (fresh == '1' || fresh == freshOf(value)) await to.write(freshMark(name), freshOf(value));
    await from.delete(freshMark(name));
  }
  try {
    await writeDeviceOnly(to, name, value);
    await from.write(_movedMark(name), '1');
    // The key last: a copy left without it would be written back into it.
    for (final item in [_deviceOnlyMark(name), _copiedMark(name), _copy(name), name]) {
      await from.delete(item);
    }
    // ponytail: silent as the migration; the next start tries again.
  } on Object catch (_) {}
  return value;
}

String _copy(String name) => '$name.copy';
String _copiedMark(String name) => '$name.copied';
String _deviceOnlyMark(String name) => '$name.device_only';
String _movedMark(String name) => '$name.moved';

/// The read back checks the value only: the attribute is the store's, set by the write.
Future<void> _writeChecked(SecureStore keychain, String key, String value) async {
  await keychain.write(key, value);
  if (await keychain.read(key) != value) throw StateError('$key: read back differs');
}
