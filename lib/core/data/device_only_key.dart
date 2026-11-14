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

/// Reads [name] from a device-only [keychain] (#263), null if it has none; a keychain that cannot be read throws.
/// A legacy keychain marked moved, read alone (a Debug build, which cannot see the Data Protection keychain), throws
/// too: its null would be a new key and the release's database wiped (#270). Read through a [MovingKeychain] with no
/// key in either store, it is none: the Mac was restored from Time Machine or Migration Assistant, which bring the
/// mark but not the key, and Postino starts over empty, as iOS after a restore.
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
  if (keychain case MovingKeychain(:final to, :final from)) {
    // [to] is read first, before anything is written in the legacy keychain. A key read back and marked there always
    // wins, whatever the legacy keychain holds (a downgrade's key is not supported).
    final value = await to.read(name);
    if (value != null && await to.read(_deviceOnlyMark(name)) != null) {
      // A new key's mark that a start killed or failed before it wrote: written again, or a Debug build would wipe
      // the database. A write that fails fails the start: without the mark the database is not safe.
      if (await from.read(_movedMark(name)) == null) await from.write(_movedMark(name), '1');
      // The same key left in the legacy keychain by a move whose cleanup failed or was killed: removed now.
      if (await from.read(name) == value) await _dropLegacy(from, name);
      return value;
    }
    // Without one, the first move, or none. A key in [to] not marked is a write that did not finish (killed, or read
    // back different): no database was ever opened with it, and the move or a new key overwrites it.
    return _move(from, to, name);
  }
  if (await _readMigrating(keychain, name) case final value?) return value;
  if (await keychain.read(_movedMark(name)) != null) throw StateError('$name: moved to the Data Protection keychain');
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

/// Whether the [freshMark] value [mark] belongs to [key].
bool isFreshOf(String mark, String key) => mark == '1' || mark == freshOf(key);

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

/// Moves [name] from the legacy keychain [from] to [to] (#270), the first time only: null if [from] has no key or is
/// marked moved already. [to] has no key here, or one not marked (a write killed or read back different), which the
/// move rewrites. [from] keeps the key until [to] holds it, read back and marked, and is
/// marked moved only then, so a step that fails leaves it there: this start goes on with it, the next moves it again.
/// A key in a legacy keychain marked moved was written by an older version after a downgrade, which is not supported,
/// or came with a restored login keychain: never moved, Postino starts over.
Future<String?> _move(SecureStore from, SecureStore to, String name) async {
  if (await from.read(_movedMark(name)) != null) return null;
  final value = await _readMigrating(from, name);
  if (value == null) return null;
  if (await from.read(freshMark(name)) case final fresh?) {
    // A new key whose database is still to be wiped: the mark moves before the key, as for a new one, and leaves
    // [from] before this start wipes, or a later start would carry it again and wipe the new database. Either step
    // failing fails the start, to be tried again. A mark of another key is stale: dropped.
    if (isFreshOf(fresh, value)) await to.write(freshMark(name), freshOf(value));
    await from.delete(freshMark(name));
  }
  try {
    await writeDeviceOnly(to, name, value);
    await from.write(_movedMark(name), '1');
    // ponytail: silent as the migration; the next start tries again.
  } on Object catch (_) {
    return value;
  }
  await _dropLegacy(from, name);
  return value;
}

/// Removes the key and its marks from the legacy keychain, the key last: a copy left without it would be written back
/// into it. Only the moved mark stays.
Future<void> _dropLegacy(SecureStore from, String name) async {
  try {
    for (final item in [_deviceOnlyMark(name), _copiedMark(name), _copy(name), name]) {
      await from.delete(item);
    }
    // ponytail: silent, the next start removes what is left.
  } on Object catch (_) {}
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
