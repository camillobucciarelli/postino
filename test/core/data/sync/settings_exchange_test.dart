// The file of the Impostazioni sealed with the Chiave di sincronizzazione, its states, the migration from the file in
// clear, «Rigenera la chiave» and the Abbinamento with the code (ADR 0019, #321): devices with their own keychains on
// one fake backend standing for the file on Drive.
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/auto_labels_store.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/settings_sync.dart';
import 'package:postino/core/data/sync/settings_envelope.dart';
import 'package:postino/core/data/sync/sync_key.dart';
import 'package:postino/core/data/sync/sync_key_store.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/sync_status.dart';

import '../../../support/fake_platform.dart';
import '../../../support/fake_settings_backend.dart';

/// One device: its database, its keychain (with [key], if given) and its sync, on the file in [backend].
class _Device(final FakeSettingsBackend backend, final FakeClock clock, {final SyncKey? key}) {
  final db = PostinoDatabase.inMemory();
  final keychain = FakeSecureStore();
  late final keys = keysWith(key, keychain);
  late final settings = DeviceSettingsStore(db);
  late final labels = AutoLabelsStore(db, clock);
  late final sync = SettingsSync(db, settings, clock, FakeConnectivity(), keys, backendFor: (_) => backend);

  Future<int> dirty() => db.postinoSettingsDao.watchDirty().first;
  Future<SyncKey?> savedKey() => keys.read();
  Future<Failure?> outcome() async => (await sync.watchStatus().first)['a1']?.failure;
  Future<Set<String>> labelsOf(String account) async => (await labels.watch(account).first).keys.toSet();
}

/// A voce of the file, as the versions before the encryption wrote it.
Map<String, Object?> _voce(Object? value, {int at = 1, String device = 'old'}) => {
  'value': value,
  'updatedAt': at,
  'deviceId': device,
  'deleted': false,
};

/// The file in clear of an older Postino, at [schema].
String _plain(Map<String, Object?> entries, {int schema = 2}) =>
    jsonEncode({'schemaVersion': schema, 'entries': entries});

void main() {
  late FakeSettingsBackend file;
  late FakeClock clock;
  final devices = <_Device>[];
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<_Device> device({SyncKey? key}) async {
    final d = _Device(file, clock, key: key);
    devices.add(d);
    await d.settings.setSettingsSyncAccount('a1');
    return d;
  }

  setUp(() {
    file = FakeSettingsBackend();
    clock = FakeClock(DateTime.utc(2026, 11, 15, 9));
  });
  tearDown(() async {
    for (final d in devices) {
      await d.sync.stop();
      await d.db.close();
    }
    devices.clear();
  });

  void tick() => clock.advance(const Duration(seconds: 1));

  group('the file is sealed', () {
    test('the first device makes a key, keeps it on the device only, and writes nothing in clear', () async {
      final a = await device();
      await a.labels.setAutomatic('a1', 'L1', automatic: true);
      await a.sync.syncNow();
      final key = await a.savedKey();
      expect(key, isNotNull);
      expect(a.keychain.values.keys, containsAll([SyncKeyStore.name, '${SyncKeyStore.name}.device_only']));
      expect(file.file, isNot(contains('auto_labels')));
      expect(file.entries(key).keys, ['auto_labels/a1']);
      expect(await a.db.postinoSettingsDao.read(SyncKeyStore.name), isNull, reason: 'never in the database');
      expect(file.drops, 0, reason: 'one copy: nothing to drop');
    });

    test('voci outside the closed list (a newer Postino\'s) stay sealed in the file and never come here', () async {
      final a = await device(key: testSyncKey);
      file.file = sealedWith({
        'schemaVersion': 3,
        'entries': {'themes/x': _voce(1), 'credentials/a1': _voce('secret')},
      });
      await a.labels.setAutomatic('a1', 'L1', automatic: true);
      await a.sync.syncNow();
      expect(file.entries().keys, unorderedEquals(['themes/x', 'credentials/a1', 'auto_labels/a1']));
      expect(await a.db.postinoSettingsDao.read('themes/x'), isNull);
      expect(await a.db.postinoSettingsDao.read('credentials/a1'), isNull);
    });

    test('a fresh nonce at every write', () async {
      final a = await device(key: testSyncKey);
      await a.labels.setAutomatic('a1', 'L1', automatic: true);
      await a.sync.syncNow();
      final first = jsonDecode(file.file!) as Map<String, Object?>;
      tick();
      await a.labels.setAutomatic('a1', 'L2', automatic: true);
      await a.sync.syncNow();
      expect((jsonDecode(file.file!) as Map<String, Object?>)['nonce'], isNot(first['nonce']));
    });

    test('nothing to write and no file: no key is made yet', () async {
      final a = await device();
      await a.sync.syncNow();
      expect((await a.savedKey(), file.writes), (null, 0));
    });

    test('two copies sealed with the same key are merged into the oldest, the other dropped', () async {
      final a = await device(key: testSyncKey);
      file
        ..file = sealedWith({
          'schemaVersion': 3,
          'entries': {
            'auto_labels/a1': _voce({'L1': <String, Object?>{}}),
          },
        })
        ..duplicates = [
          sealedWith({
            'schemaVersion': 3,
            'entries': {
              'auto_labels/a2': _voce({'L2': <String, Object?>{}}),
            },
          }),
        ];
      await a.sync.syncNow();
      expect(file.entries().keys, unorderedEquals(['auto_labels/a1', 'auto_labels/a2']));
      expect((file.duplicates.length, file.drops), (0, 1));
      expect(await a.labelsOf('a2'), {'L2'});
    });

    test(
      'a copy sealed with another key (two first writes at once) is dropped; an unreadable one leaves all alone',
      () async {
        final a = await device(key: testSyncKey);
        final other = sealedWith({'schemaVersion': 3, 'entries': <String, Object?>{}}, SyncKey.random());
        file
          ..file = sealedWith({
            'schemaVersion': 3,
            'entries': {
              'auto_labels/a1': _voce({'L1': <String, Object?>{}}),
            },
          })
          ..duplicates = [other];
        await a.sync.syncNow();
        expect(file.duplicates, isEmpty);

        file.duplicates = ['{"postinoEncrypted":1,"keyId":"${testSyncKey.id}","nonce":"AAAA","ciphertext":"AAAA"}'];
        final writes = file.writes;
        await a.sync.syncNow();
        expect((file.duplicates.length, file.writes, await a.outcome()), (1, writes, null));
      },
    );
  });

  group('a file that cannot be read is never overwritten', () {
    for (final (name, broken) in [
      (
        'a tag that does not match',
        (String s) => s.replaceFirst(RegExp('"ciphertext":"[A-Za-z0-9+/]'), '"ciphertext":"A'),
      ),
      ('a newer envelope', (String s) => s.replaceFirst('"postinoEncrypted":1', '"postinoEncrypted":2')),
      ('a malformed envelope', (String s) => '{"postinoEncrypted":1,"keyId":"${testSyncKey.id}"}'),
    ]) {
      test(name, () async {
        final a = await device(key: testSyncKey);
        final sealed = sealedWith({
          'schemaVersion': 3,
          'entries': {
            'auto_labels/a2': _voce({'X': <String, Object?>{}}),
          },
        });
        final damaged = broken(sealed);
        // The flip may land on the same character: then flip it the other way.
        file.file = damaged == sealed ? sealed.replaceFirst('"ciphertext":"A', '"ciphertext":"B') : damaged;
        final before = file.file;
        await a.labels.setAutomatic('a1', 'L1', automatic: true);
        await a.sync.syncNow();
        expect((file.file, file.writes, await a.dirty()), (before, 0, 1));
        expect(await a.outcome(), isA<UnexpectedFailure>());
      });
    }
  });

  group('Non abbinato and Chiave non più valida', () {
    late _Device a;
    setUp(() async {
      a = await device(key: testSyncKey);
      await a.labels.setAutomatic('a1', 'L1', automatic: true);
      await a.sync.syncNow();
    });

    test('a device without the key reads nothing, writes nothing and makes no key: it asks to be paired', () async {
      final b = await device();
      await b.labels.setAutomatic('a2', 'X', automatic: true);
      final before = file.file;
      await b.sync.syncNow();
      expect((file.file, file.writes), (before, 1));
      expect(await b.labelsOf('a1'), isEmpty);
      expect((await b.savedKey(), await b.dirty()), (null, 1));
      expect(await b.outcome(), isA<SyncNotPairedFailure>());
      expect((await b.sync.watchStatus().first)['a1']?.failed, isTrue);
    });

    test('a device with another key does the same, and its voci wait to be uploaded', () async {
      final b = await device(key: SyncKey.random());
      await b.labels.setAutomatic('a2', 'X', automatic: true);
      final before = file.file;
      await b.sync.syncNow();
      expect((file.file, (await b.labelsOf('a1')).length, await b.dirty()), (before, 0, 1));
      expect(await b.outcome(), isA<SyncKeyInvalidFailure>());
    });
  });

  group('the migration from the file in clear', () {
    test('the first device updated merges it, makes the key and seals it', () async {
      file.file = _plain({
        'auto_labels/a2': _voce({'X': <String, Object?>{}}),
      });
      final a = await device();
      await a.labels.setAutomatic('a1', 'L1', automatic: true);
      await a.sync.syncNow();
      final key = await a.savedKey();
      expect(file.entries(key).keys, unorderedEquals(['auto_labels/a1', 'auto_labels/a2']));
      expect(await a.labelsOf('a2'), {'X'});
      expect((await a.dirty(), await a.outcome()), (0, null));
    });

    test('it never takes the credentials/ voci of a file in clear', () async {
      file.file = _plain({
        'auto_labels/a2': _voce({'X': <String, Object?>{}}),
        'credentials/a2': _voce({'password': 'p'}),
      });
      final a = await device();
      await a.sync.syncNow();
      expect(file.entries(await a.savedKey()).keys, ['auto_labels/a2']);
    });

    test('a file in clear above schema 2 is no legitimate one: nothing applied, no key, not overwritten', () async {
      final plain = _plain({
        'auto_labels/a2': _voce({'X': <String, Object?>{}}),
      }, schema: 3);
      file.file = plain;
      final a = await device();
      await a.labels.setAutomatic('a1', 'L1', automatic: true);
      await a.sync.syncNow();
      expect((file.file, await a.savedKey(), (await a.labelsOf('a2')).length), (plain, null, 0));
      expect(await a.outcome(), isA<UnexpectedFailure>());
    });

    test('a device with a key never trusts a file in clear: nothing applied, overwritten sealed', () async {
      final a = await device(key: testSyncKey);
      await a.labels.setAutomatic('a1', 'L1', automatic: true);
      file.file = _plain({
        'auto_labels/a2': _voce({'X': <String, Object?>{}}, at: clock.now().millisecondsSinceEpoch + 1),
      });
      await a.sync.syncNow();
      expect(await a.labelsOf('a2'), isEmpty);
      expect(file.entries().keys, ['auto_labels/a1']);
      expect(await a.savedKey(), isA<SyncKey>().having((k) => k.id, 'id', testSyncKey.id));
    });

    test('two devices that migrate at once: the loser asks to be paired, and after it no voce is lost', () async {
      file.file = _plain({
        'auto_labels/old': _voce({'O': <String, Object?>{}}),
      });
      final a = await device();
      final b = await device();
      await a.labels.setAutomatic('a1', 'A', automatic: true);
      await b.labels.setAutomatic('a2', 'B', automatic: true);
      // Both read the file in clear before either writes.
      final gate = file.readGate = Completer<void>();
      final cycles = [a.sync.syncNow(), b.sync.syncNow()];
      await pumpEventQueue();
      gate.complete();
      await Future.wait(cycles);
      file.readGate = null;
      final ka = await a.savedKey();
      final kb = await b.savedKey();
      expect(ka!.id, isNot(kb!.id));
      // The last write won: B's. A's voce is not in the file, A finds the key no longer valid.
      expect((jsonDecode(file.file!) as Map<String, Object?>)['keyId'], kb.id);
      await a.sync.syncNow();
      expect(await a.outcome(), isA<SyncKeyInvalidFailure>());

      // A is paired with B's code: its voce goes back into the file, and B gets it.
      expect(await a.sync.pair((await b.sync.pairingCode())!), isA<Ok<void>>());
      await pumpEventQueue(times: 50);
      await b.sync.syncNow();
      expect(file.entries(kb).keys, unorderedEquals(['auto_labels/old', 'auto_labels/a1', 'auto_labels/a2']));
      for (final d in [a, b]) {
        for (final (account, label) in [('old', 'O'), ('a1', 'A'), ('a2', 'B')]) {
          expect(await d.labelsOf(account), {label});
        }
      }
    });
  });

  group('«Rigenera la chiave»', () {
    test('with a file it reads: merged first, then sealed with the new key; the others must pair again', () async {
      final a = await device(key: testSyncKey);
      final b = await device(key: testSyncKey);
      await b.labels.setAutomatic('a2', 'B', automatic: true);
      await b.sync.syncNow();
      await a.labels.setAutomatic('a1', 'A', automatic: true);

      expect(await a.sync.regenerateKey(), isA<Ok<void>>());
      final key = (await a.savedKey())!;
      expect(key.id, isNot(testSyncKey.id));
      expect(file.entries(key).keys, unorderedEquals(['auto_labels/a1', 'auto_labels/a2']));
      await b.sync.syncNow();
      expect(await b.outcome(), isA<SyncKeyInvalidFailure>());
    });

    test('with a file it does not read: overwritten with the voci of this device', () async {
      final a = await device();
      file.file = sealedWith({
        'schemaVersion': 3,
        'entries': {
          'auto_labels/lost': _voce({'X': <String, Object?>{}}),
        },
      }, SyncKey.random());
      await a.labels.setAutomatic('a1', 'A', automatic: true);
      expect(await a.sync.regenerateKey(), isA<Ok<void>>());
      expect(file.entries(await a.savedKey()).keys, ['auto_labels/a1']);
      expect(await a.outcome(), isNull);
    });

    test('a write that fails keeps the old key: the device still reads the file, and can try again', () async {
      final a = await device(key: testSyncKey);
      await a.labels.setAutomatic('a1', 'A', automatic: true);
      await a.sync.syncNow();
      file.writeFailure = const OfflineFailure();
      expect(await a.sync.regenerateKey(), isA<Err<void>>());
      expect((await a.savedKey())!.id, testSyncKey.id);
      file.writeFailure = null;
      await a.sync.syncNow();
      expect(await a.outcome(), isNull);
      expect(await a.sync.regenerateKey(), isA<Ok<void>>());
      expect(file.entries((await a.savedKey())!).keys, ['auto_labels/a1']);
    });

    test('offline it does nothing: no key, no write', () async {
      final a = await device(key: testSyncKey);
      file.readFailure = const OfflineFailure();
      expect(await a.sync.regenerateKey(), isA<Err<void>>());
      expect(((await a.savedKey())!.id, file.writes), (testSyncKey.id, 0));
    });

    test('a file from a newer Postino is never overwritten, not even by a new key', () async {
      final a = await device(key: testSyncKey);
      file.file = sealedWith({'schemaVersion': 99, 'entries': <String, Object?>{}});
      final newer = file.file;
      await a.labels.setAutomatic('a1', 'A', automatic: true);
      expect(await a.sync.regenerateKey(), isA<Err<void>>());
      expect(((await a.savedKey())!.id, file.file), (testSyncKey.id, newer));
    });
  });

  group('the Abbinamento with the code', () {
    late _Device a;
    late _Device b;
    setUp(() async {
      a = await device(key: testSyncKey);
      await a.labels.setAutomatic('a1', 'A', automatic: true);
      await a.sync.syncNow();
      b = await device();
    });

    test('the right code, typed by hand: the key is kept, the device syncs', () async {
      final code = (await a.sync.pairingCode())!;
      final typed = [for (var i = 0; i < code.length; i += 4) code.substring(i, (i + 4).clamp(0, code.length))]
          .join(' ');
      expect(await b.sync.pair(typed.toLowerCase()), isA<Ok<void>>());
      expect((await b.savedKey())!.id, testSyncKey.id);
      await pumpEventQueue(times: 50);
      expect(await b.labelsOf('a1'), {'A'});
      expect(await b.outcome(), isNull);
    });

    test('a malformed code: «codice non valido», nothing saved, nothing read', () async {
      final reads = file.reads;
      expect(
        await b.sync.pair('P1 ABCD'),
        isA<Err<void>>().having((e) => e.failure, 'failure', isA<PairingCodeFailure>()),
      );
      expect((await b.savedKey(), file.reads), (null, reads));
    });

    test('the code of another key (another Account di sincronizzazione): «codice non valido», nothing saved', () async {
      expect(
        await b.sync.pair(SyncKey.random().code),
        isA<Err<void>>().having((e) => e.failure, 'failure', isA<PairingCodeFailure>()),
      );
      expect(await b.savedKey(), isNull);
    });

    test('offline or Drive failing: nothing saved', () async {
      file.readFailure = const OfflineFailure();
      expect(
        await b.sync.pair(testSyncKey.code),
        isA<Err<void>>().having((e) => e.failure, 'failure', isA<OfflineFailure>()),
      );
      expect(await b.savedKey(), isNull);
    });

    test('no file, or one in clear: nothing to pair, nothing saved', () async {
      for (final remote in [null, _plain({})]) {
        file.file = remote;
        expect(
          await b.sync.pair(testSyncKey.code),
          isA<Err<void>>().having((e) => e.failure, 'failure', isA<NothingToPairFailure>()),
        );
        expect(await b.savedKey(), isNull);
      }
    });

    test('a device whose key is no longer valid pairs again and keeps one key', () async {
      final c = await device(key: SyncKey.random());
      expect(await c.sync.pair(testSyncKey.code), isA<Ok<void>>());
      expect((await c.savedKey())!.id, testSyncKey.id);
    });

    test('the code and the key never reach the outcome nor the failures', () async {
      await b.sync.syncNow();
      final shown = '${await b.sync.watchStatus().first} ${await b.sync.pair('${testSyncKey.code}X')}';
      expect(shown, isNot(contains(testSyncKey.code.substring(2, 20))));
      expect(shown, isNot(contains(testSyncKey.encode())));
    });
  });

  test('a cycle, a pairing and a regeneration never run at once', () async {
    final a = await device(key: testSyncKey);
    final gate = file.readGate = Completer<void>();
    final jobs = [a.sync.syncNow(), a.sync.regenerateKey(), a.sync.pair(testSyncKey.code), a.sync.syncNow()];
    await pumpEventQueue();
    expect(file.reads, 1);
    gate.complete();
    await Future.wait(jobs);
    expect(file.maxInFlight, 1);
  });

  test('the status of a device to pair is a failure, then a success once paired', () async {
    final a = await device(key: testSyncKey);
    await a.labels.setAutomatic('a1', 'A', automatic: true);
    await a.sync.syncNow();
    final b = await device();
    await b.sync.syncNow();
    expect(
      (await b.sync.watchStatus().first)['a1'],
      isA<SyncStatus>().having((s) => s.failure, 'failure', isA<SyncNotPairedFailure>()),
    );
    await b.sync.pair(testSyncKey.code);
    await pumpEventQueue(times: 50);
    expect((await b.sync.watchStatus().first)['a1'], SyncStatus(syncedAt: clock.now()));
  });

  test('a sealed file opens only with its key: the decrypted content is what was written', () async {
    final a = await device(key: testSyncKey);
    await a.labels.setAutomatic('a1', 'A', automatic: true);
    await a.sync.syncNow();
    expect(openSettings(file.file!, SyncKey.random()), isA<LockedCopy>());
    expect(openSettings(file.file!, testSyncKey), isA<OpenedCopy>());
  });
}
