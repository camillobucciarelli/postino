import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_only_key.dart';

import '../../support/fake_platform.dart';

void main() {
  const name = 'database_key';
  const key = 'k3y';

  test('a key an older version saved is rewritten device only, once, its copy kept', () async {
    final keychain = FakeSecureStore()..values[name] = key;

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [
      '$name.copy',
      '$name.copied',
      name,
      '$name.device_only',
    ], reason: 'copied before the rewrite');
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});

    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, isEmpty);
  });

  test('a key saved by writeDeviceOnly is never migrated', () async {
    final keychain = FakeSecureStore();
    await writeDeviceOnly(keychain, name, key);
    keychain.writes.clear();

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, isEmpty);
  });

  test('no key: nothing to migrate', () async {
    final keychain = FakeSecureStore();
    expect(await readDeviceOnly(keychain, name), isNull);
    expect(keychain.values, isEmpty);
  });

  test('a failed copy leaves the key as it was, and the next start migrates', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add('$name.copy');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key});

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.device_only'], isNotNull);
  });

  test('a rewrite that lost the key (deleted, not added) is recovered from the copy, never rewritten', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add(name);

    expect(await readDeviceOnly(keychain, name), key, reason: 'this start still opens the database');
    expect(keychain.values, {'$name.copy': key, '$name.copied': '1'});

    // The next start fails again: the copy, the only one left, is not touched.
    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [name]);
    expect(keychain.values, {'$name.copy': key, '$name.copied': '1'});

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('a rewrite read back different is restored from the copy, never the other way round', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..corruptWrites.add(name);

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.copy'], key);
    expect(keychain.values['$name.device_only'], isNull, reason: 'tried again at the next start');

    // The next start finds the key wrong and the copy right: the copy wins, and is not written.
    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [name]);
    expect(keychain.values['$name.copy'], key);

    keychain.corruptWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('a copy read back different is never trusted: the key, untouched, is copied again', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..corruptWrites.add('$name.copy');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values[name], key, reason: 'not rewritten without a good copy');
    expect(keychain.values['$name.copied'], isNull);

    keychain.corruptWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('a copy saved but not marked as checked is copied again from the key', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add('$name.copied');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, ['$name.copy', '$name.copied'], reason: 'the key not rewritten');

    keychain.failingWrites.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.device_only'], '1');
  });

  test('a rewrite checked but not marked done is finished from the copy at the next start', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failingWrites.add('$name.device_only');

    expect(await readDeviceOnly(keychain, name), key);
    keychain.failingWrites.clear();
    keychain.writes.clear();
    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.writes, [name, '$name.device_only']);
  });

  test('only a checked copy is left (the key lost elsewhere): it is the key', () async {
    final keychain = FakeSecureStore()
      ..values['$name.copy'] = key
      ..values['$name.copied'] = '1';

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values[name], key);
    expect(keychain.writes, [name, '$name.device_only']);
  });

  test('a key deleted after the migration is restored from its copy', () async {
    final keychain = FakeSecureStore()
      ..values['$name.copy'] = key
      ..values['$name.copied'] = '1'
      ..values['$name.device_only'] = '1';

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values[name], key);
  });

  test('only an unchecked copy left: the only value, better than a new key that wipes the database', () async {
    final keychain = FakeSecureStore()..values['$name.copy'] = key;

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values, {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'});
  });

  test('the only copy left is never written: a failed write would lose the last key', () async {
    final keychain = FakeSecureStore()
      ..values['$name.copy'] = key
      ..failingWrites.add('$name.copy');

    expect(await readDeviceOnly(keychain, name), key);
    expect(keychain.values['$name.copy'], key);
  });

  test('a key restored from its copy and read back different is not taken as migrated at the next start', () async {
    final keychain = FakeSecureStore()
      ..values['$name.copy'] = key
      ..values['$name.copied'] = '1'
      ..values['$name.device_only'] = '1'
      ..corruptWrites.add(name);

    expect(await readDeviceOnly(keychain, name), key);
    keychain.corruptWrites.clear();
    expect(await readDeviceOnly(keychain, name), key, reason: 'the copy, not the wrong key');
    expect(keychain.values[name], key);
  });

  test('a copy that cannot be read is an error, never a missing copy', () async {
    final keychain = _FailingRead('$name.copy')..values[name] = key;
    await expectLater(readDeviceOnly(keychain, name), throwsException);
    expect(keychain.writes, isEmpty);
  });

  test('a new key read back different is an error, not a key the next start cannot open with', () async {
    final keychain = FakeSecureStore()..corruptWrites.add(name);
    await expectLater(writeDeviceOnly(keychain, name, key), throwsStateError);
    expect(keychain.values['$name.device_only'], isNull, reason: 'migrated, as any key found, at the next start');
  });

  test('a keychain that cannot be read is an error, never a missing key', () async {
    final keychain = FakeSecureStore()
      ..values[name] = key
      ..failure = Exception('keychain bloccato');
    await expectLater(readDeviceOnly(keychain, name), throwsException);
  });

  group('moved from the legacy keychain (macOS release, #270)', () {
    const migrated = {name: key, '$name.copy': key, '$name.copied': '1', '$name.device_only': '1'};
    late FakeSecureStore legacy;
    late FakeSecureStore dataProtection;
    late MovingKeychain keychain;
    setUp(() {
      legacy = FakeSecureStore()..values.addAll(migrated);
      dataProtection = FakeSecureStore();
      keychain = MovingKeychain(dataProtection, legacy);
    });

    /// The same key in [store], and no fresh mark anywhere: never a new key, never the database wiped.
    void expectKeptIn(FakeSecureStore store) {
      expect(store.values[name], key);
      expect(dataProtection.values['$name.fresh'], isNull);
      expect(legacy.values['$name.fresh'], isNull);
    }

    test('the key moves, checked, and only then leaves the legacy keychain, a mark in its place', () async {
      expect(await readDeviceOnly(keychain, name), key);
      expect(dataProtection.values, {name: key, '$name.device_only': '1'});
      expect(dataProtection.writes, [name, '$name.device_only'], reason: 'saved device only: nothing to migrate');
      expect(legacy.values, {'$name.moved': '1'});

      dataProtection.writes.clear();
      legacy.writes.clear();
      expect(await readDeviceOnly(keychain, name), key);
      expect([...dataProtection.writes, ...legacy.writes], isEmpty);
    });

    test('a key never migrated device only is migrated in the legacy keychain first, then moved', () async {
      legacy.values
        ..clear()
        ..[name] = key;
      expect(await readDeviceOnly(keychain, name), key);
      expect(legacy.values, {'$name.moved': '1'});
      expectKeptIn(dataProtection);
    });

    for (final (step, fail) in <(String, void Function(FakeSecureStore, FakeSecureStore))>[
      ('the write', (to, from) => to.failingWrites.add(name)),
      ('the read back', (to, from) => to.corruptWrites.add(name)),
      ('the device only mark', (to, from) => to.failingWrites.add('$name.device_only')),
      ('the moved mark', (to, from) => from.failingWrites.add('$name.moved')),
    ]) {
      test('$step failing leaves the key in the legacy keychain: this start goes on with it, the next moves', () async {
        fail(dataProtection, legacy);
        expect(await readDeviceOnly(keychain, name), key);
        expectKeptIn(legacy);

        dataProtection
          ..failingWrites.clear()
          ..corruptWrites.clear();
        legacy.failingWrites.clear();
        expect(await readDeviceOnly(keychain, name), key);
        expectKeptIn(dataProtection);
        expect(legacy.values, {'$name.moved': '1'});
      });
    }

    for (final item in ['$name.device_only', '$name.copied', '$name.copy', name]) {
      test('a cleanup failing at $item leaves the rest, removed at the next start', () async {
        legacy = _FailingDelete(item)..values.addAll(migrated);
        keychain = MovingKeychain(dataProtection, legacy);
        expect(await readDeviceOnly(keychain, name), key);
        expectKeptIn(dataProtection);
        expect(legacy.values[name], key, reason: 'the key last');

        keychain = MovingKeychain(dataProtection, FakeSecureStore()..values.addAll(legacy.values));
        expect(await readDeviceOnly(keychain, name), key);
        expectKeptIn(dataProtection);
        expect(keychain.from, isA<FakeSecureStore>().having((s) => s.values, 'values', {'$name.moved': '1'}));
      });
    }

    test('a new key marks the legacy keychain moved, after the key: a Debug build then fails', () async {
      legacy.values.clear();
      await writeDeviceOnly(keychain, name, key);
      expect(dataProtection.values, {name: key, '$name.device_only': '1'});
      expect(legacy.values, {'$name.moved': '1'});
      await expectLater(readDeviceOnly(legacy, name), throwsStateError);
      expect(await readDeviceOnly(keychain, name), key);
    });

    test(
      'a legacy key without the moved mark never replaces a different key in use (an old keychain restored)',
      () async {
        dataProtection.values.addAll({name: 'in use', '$name.device_only': '1'});
        expect(await readDeviceOnly(keychain, name), 'in use');
        expect(dataProtection.values, {name: 'in use', '$name.device_only': '1'});
        expect(legacy.values, migrated, reason: 'left as it is');
        expect(legacy.writes, isEmpty);
      },
    );

    test('a moved mark that cannot be written fails the start: without it a Debug build would wipe', () async {
      legacy.values.clear();
      dataProtection.values.addAll({name: key, '$name.device_only': '1'});
      legacy.failingWrites.add('$name.moved');
      await expectLater(readDeviceOnly(keychain, name), throwsException);

      legacy.failingWrites.clear();
      expect(await readDeviceOnly(keychain, name), key);
      expect(legacy.values, {'$name.moved': '1'});
    });

    test('a Data Protection keychain that cannot be read fails the start before the legacy one is touched', () async {
      final locked = FakeSecureStore()..failure = Exception('-34018');
      await expectLater(readDeviceOnly(MovingKeychain(locked, legacy), name), throwsException);
      expect(legacy.values, migrated);
      expect([...locked.writes, ...legacy.writes], isEmpty);

      final notMigrated = FakeSecureStore()..values[name] = key;
      await expectLater(readDeviceOnly(MovingKeychain(locked, notMigrated), name), throwsException);
      expect(notMigrated.writes, isEmpty, reason: 'not even the migration of #263');
    });

    test('a legacy key wins over the moved one, the key it replaces kept: the database tells which opens it', () async {
      dataProtection.values.addAll({name: 'in use', '$name.device_only': '1'});
      legacy.values['$name.moved'] = '1';
      expect(await readDeviceOnly(keychain, name), key);
      expectKeptIn(dataProtection);
      expect(dataProtection.values['$name.replaced'], 'in use');
      expect(legacy.values, {'$name.moved': '1'});
    });

    test('a slot holding another replaced key: nothing replaced, nothing lost', () async {
      dataProtection.values.addAll({name: 'in use', '$name.device_only': '1', '$name.replaced': 'older'});
      legacy.values['$name.moved'] = '1';
      expect(await readDeviceOnly(keychain, name), 'in use');
      expect(dataProtection.values[name], 'in use');
      expect(dataProtection.values['$name.replaced'], 'older');
      expect(legacy.values[name], key);
    });

    test('a fresh mark moves with its key, once: the database it wiped is never wiped again', () async {
      legacy.values['$name.fresh'] = '1';
      legacy.deleteFailure = Exception('keychain: delete failed');
      await expectLater(readDeviceOnly(keychain, name), throwsException, reason: 'it would be carried again');
      expect(legacy.values['$name.fresh'], '1');

      legacy.deleteFailure = null;
      expect(await readDeviceOnly(keychain, name), key);
      expect(dataProtection.values['$name.fresh'], freshOf(key), reason: 'of this key');
      expect(legacy.values, {'$name.moved': '1'});

      dataProtection.values.remove('$name.fresh'); // wiped by PostinoDatabase.open
      expect(await readDeviceOnly(keychain, name), key);
      expect(dataProtection.values['$name.fresh'], isNull);
    });

    test('a legacy fresh mark of another key is stale: dropped, not moved', () async {
      legacy.values['$name.fresh'] = freshOf('another');
      expect(await readDeviceOnly(keychain, name), key);
      expect(dataProtection.values['$name.fresh'], isNull);
      expect(legacy.values, {'$name.moved': '1'});
    });

    test('a new key killed at any step: the next start that reads it marks the legacy keychain moved', () async {
      for (var budget = 0; ; budget++) {
        final ops = _Budget(budget);
        final from = _Killable(ops);
        final to = _Killable(ops);
        try {
          await writeDeviceOnly(MovingKeychain(to, from), name, key);
        } on _Killed catch (_) {
          // the process died here
        }
        final legacy = FakeSecureStore()..values.addAll(from.values);
        final read = await readDeviceOnly(MovingKeychain(FakeSecureStore()..values.addAll(to.values), legacy), name);
        // Killed before the key was saved: none, as at a first launch (no database yet). Saved: always found.
        expect(read, to.values[name] == key ? key : isNull, reason: 'killed after $budget operations');
        // The moved mark comes after the key: with the key a Debug build fails, without it nothing is there yet.
        await expectLater(
          readDeviceOnly(legacy, name),
          read != null ? throwsStateError : completion(isNull),
          reason: 'a Debug build after $budget operations',
        );
        if (!ops.killed) break;
      }
    });

    test(
      'moved and found in neither store: none for the release (a restored Mac), an error for a Debug build',
      () async {
        legacy.values
          ..clear()
          ..['$name.moved'] = '1';
        expect(await readDeviceOnly(keychain, name), isNull);
        await expectLater(readDeviceOnly(legacy, name), throwsStateError, reason: 'a Debug build on the same Mac');
        expect([...dataProtection.writes, ...legacy.writes], isEmpty);
      },
    );

    // A start killed after any keychain operation of the move, then started again: the key is never lost, so the
    // release never reads none (a new key, the database wiped), and a Debug build never gets a key of its own.
    for (final (label, start) in [
      ('migrated', migrated),
      ('not yet migrated', const {name: key}),
      ('with a fresh mark', {...migrated, '$name.fresh': '1'}),
    ]) {
      test('a move killed at any step, $label, keeps the key', () async {
        for (var budget = 0; ; budget++) {
          final ops = _Budget(budget);
          final from = _Killable(ops)..values.addAll(start);
          final to = _Killable(ops);
          try {
            await readDeviceOnly(MovingKeychain(to, from), name);
          } on _Killed catch (_) {
            // the process died here
          } on Object catch (_) {
            // a step that failed: the start fails, tried again
          }
          final restart = MovingKeychain(
            FakeSecureStore()..values.addAll(to.values),
            FakeSecureStore()..values.addAll(from.values),
          );
          final debug = FakeSecureStore()..values.addAll(from.values);
          expect(await readDeviceOnly(restart, name), key, reason: 'killed after $budget operations');
          // The legacy keychain loses its key and copy only after the moved mark: a Debug build reads the key or fails.
          if (debug.values.containsKey(name) || debug.values.containsKey('$name.copy')) {
            expect(await readDeviceOnly(debug, name), key, reason: 'a Debug build after $budget operations');
          } else {
            await expectLater(readDeviceOnly(debug, name), throwsStateError, reason: 'moved, after $budget operations');
          }
          if (!ops.killed) break;
        }
      });
    }

    test('a keychain that cannot be read is an error, never a missing key', () async {
      dataProtection.failure = Exception('-34018');
      legacy.values.clear();
      await expectLater(readDeviceOnly(keychain, name), throwsException);
      expect([...dataProtection.writes, ...legacy.writes], isEmpty, reason: 'no new key, no fresh mark');

      dataProtection.failure = null;
      legacy
        ..values.addAll(migrated)
        ..failure = Exception('keychain bloccato');
      await expectLater(readDeviceOnly(keychain, name), throwsException);
      expect(dataProtection.writes, isEmpty);
    });

    test('nothing in either keychain: none, as at a first launch', () async {
      legacy.values.clear();
      expect(await readDeviceOnly(keychain, name), isNull);
      expect([...dataProtection.writes, ...legacy.writes], isEmpty);
    });

    test('reads, writes and deletes go to the Data Protection keychain', () async {
      await keychain.write('x', '1');
      expect(dataProtection.values['x'], '1');
      expect(await keychain.read('x'), '1');
      await keychain.delete('x');
      expect(dataProtection.values, isEmpty);
      expect(legacy.writes, isEmpty);
    });
  });
}

/// The keychain operations a process makes before it dies.
class _Budget(var int left) {
  var killed = false;

  void spend() {
    if (left-- <= 0) {
      killed = true;
      throw _Killed();
    }
  }
}

class _Killed() implements Exception {}

/// A keychain in a process that dies once the shared [ops] are spent: nothing after that reaches it.
class _Killable(final _Budget ops) extends FakeSecureStore {
  @override
  Future<String?> read(String key) async {
    ops.spend();
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    ops.spend();
    return super.write(key, value);
  }

  @override
  Future<void> delete(String key) async {
    ops.spend();
    return super.delete(key);
  }
}

/// A keychain whose deletes of [key] throw.
class _FailingDelete(final String key) extends FakeSecureStore {
  @override
  Future<void> delete(String key) async => key == this.key ? throw Exception('delete failed') : super.delete(key);
}

/// A keychain whose reads of [key] throw: that item locked, the others readable.
class _FailingRead(final String key) extends FakeSecureStore {
  @override
  Future<String?> read(String key) async => key == this.key ? throw Exception('keychain bloccato') : super.read(key);
}
