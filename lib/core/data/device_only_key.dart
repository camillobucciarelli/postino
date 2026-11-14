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
    if (await _move(from, to, name) case final value?) return value;
    // The legacy keychain loses the key only once [to] holds it, read back: none in both is no key on this Mac.
    var value = await _readMigrating(to, name);
    // Only the keys a moved one replaced, the key lost by an overwrite that failed half way: the latest is the key
    // again, and the database still tries them all.
    final kept = value == null ? await readKept(to, name) : const <String>[];
    if (kept.isNotEmpty) {
      value = kept.last;
      try {
        await writeDeviceOnly(to, name, value);
        // ponytail: silent, the kept keys stay until the key is back in its item (PostinoDatabase.open).
      } on Object catch (_) {}
    }
    // A new key's mark that a start killed or failed before it wrote: written again, or a Debug build would wipe the
    // database. A write that fails fails the start: without the mark the database is not safe.
    if (value != null && await from.read(_movedMark(name)) == null) await from.write(_movedMark(name), '1');
    return value;
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

/// The [i]th key in use that a moved one replaced (#270), kept until the database opens with one of them. One item
/// each, written once and never rewritten: a write that fails half way (deleted, not added) loses no other key.
String replacedMark(String name, int i) => '$name.replaced.$i';

/// The kept keys of [name], oldest first: the items from 0 up to the first missing.
Future<List<String>> readKept(SecureStore keychain, String name) async {
  final kept = <String>[];
  for (;;) {
    final key = await keychain.read(replacedMark(name, kept.length));
    if (key == null) return kept;
    kept.add(key);
  }
}

/// Forgets the [count] kept keys of [name], newest first: a delete that fails leaves only older ones, still read.
Future<void> dropKept(SecureStore keychain, String name, int count) async {
  for (var i = count - 1; i >= 0; i--) {
    await keychain.delete(replacedMark(name, i));
  }
}

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

/// Moves [name] from the legacy keychain [from] to [to] (#270), null if [from] has none. [from] keeps it until [to]
/// holds it, read back and marked, so a step that fails leaves it there: this start goes on with it, the next moves it
/// again. A key in [from] next to the moved mark wins over a different one in [to]: an older version wrote it after a
/// downgrade, and its database with it. The keys it replaces are kept ([replacedMark]) until the database tells which
/// one opens it (`PostinoDatabase.open`): never lost, whichever keychain was restored. One without the mark does not
/// replace a different key already in use in [to] (an old login keychain restored, say): it is left as it is. Only
/// the moved mark is left in [from].
Future<String?> _move(SecureStore from, SecureStore to, String name) async {
  // Read before any write: a Data Protection keychain that cannot be read fails the start, [from] untouched.
  final current = await to.read(name);
  final marked = await to.read(_deviceOnlyMark(name)) != null;
  final copy = await to.read(_copy(name));
  final kept = await readKept(to, name);
  final value = await _readMigrating(from, name);
  if (value == null) return null;
  if (current != null && current != value && marked && await from.read(_movedMark(name)) == null) return current;
  // Every key of [to] it replaces, the key or a copy a #263 migration left there, joins the ones an earlier move
  // replaced: whichever opens the file wins, so none is lost and a stale one left by a cleanup that failed never
  // shuts out a newer key. A failed write fails the start, before the key in use is touched.
  for (final key in {current, copy}.nonNulls.where((k) => k != value && !kept.contains(k))) {
    await _writeChecked(to, replacedMark(name, kept.length), key);
    kept.add(key);
  }
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
