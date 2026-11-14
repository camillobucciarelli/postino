import 'dart:io';
import 'dart:isolate';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/database_lock.dart';
import 'package:postino/core/data/device_only_key.dart';
import 'package:postino/core/data/error_log/encrypted_error_log.dart';
import 'package:postino/core/data/error_log/log_keys.dart';
import 'package:postino/core/data/postino_database.dart';

import 'package:postino/core/domain/platform_services.dart';

import 'package:sqlite3/sqlite3.dart';

import '../../support/fake_platform.dart';

/// One keychain seen by two isolates, each with its own [PostinoDatabase.keyFrom] cache: a read returns what was
/// there when it was asked; a read of [slow] answers 200 ms later (the other isolate goes on meanwhile).
class _IsolateView(final Map<String, String> values, {final String? slow}) implements SecureStore {
  static var deletes = 0;

  @override
  Future<String?> read(String key) async {
    final value = values[key];
    await Future<void>.delayed(key == slow ? const Duration(milliseconds: 200) : Duration.zero);
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    await Future<void>.delayed(Duration.zero);
    deletes++;
    values.remove(key);
  }
}

/// A keychain that says when the fresh mark is read: under the lock, just before the database opens.
class _SignalsFreshRead(final SendPort port) extends FakeSecureStore {
  @override
  Future<String?> read(String key) {
    if (key == 'database_key.fresh') port.send(null);
    return super.read(key);
  }
}

void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('postino_db');
    path = '${dir.path}/postino.db';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> insertAccount(PostinoDatabase db) =>
      db.customStatement("INSERT INTO accounts VALUES ('a1', 'a@example.com', 'gmail', 1, 0, 'attivo')");

  /// A keychain holding a key, not the file's.
  FakeSecureStore otherKey() => FakeSecureStore()..values['database_key'] = 'ab' * 32;
  Future<int> accounts(PostinoDatabase db) async =>
      (await db.customSelect('SELECT count(*) AS n FROM accounts').getSingle()).read<int>('n');

  test('the file is encrypted and reopens with the key kept in the keychain', () async {
    final keychain = FakeSecureStore();
    final db = await PostinoDatabase.open(path, keychain);
    await insertAccount(db);
    await db.close();

    expect(
      File(path).readAsBytesSync().sublist(0, 15),
      isNot('SQLite format 3'.codeUnits),
      reason: 'a plain SQLite file starts with its magic header',
    );
    final again = await PostinoDatabase.open(path, keychain);
    expect(await accounts(again), 1);
    await again.close();
  });

  test('with another key the file cannot be read', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    await insertAccount(db);
    await db.close();

    expect(() => PostinoDatabase.open(path, otherKey()), throwsA(anything));
  });

  test('a file with no key in the keychain (restored on another device, #263) starts over empty', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    await insertAccount(db);
    await db.close();

    final restored = FakeSecureStore();
    final again = await PostinoDatabase.open(path, restored);
    expect(await accounts(again), 0);
    await insertAccount(again);
    await again.close();
    final third = await PostinoDatabase.open(path, restored);
    expect(await accounts(third), 1, reason: 'reopens with the new key, not wiped again');
    await third.close();
  });

  test('a new key is created with the fresh mark bound to it, not the generic 1 (#270)', () async {
    final keychain = FakeSecureStore();
    final key = await PostinoDatabase.keyFrom(keychain, path);
    expect(keychain.values['database_key'], key);
    expect(keychain.values['database_key.fresh'], freshOf(key));
    expect(keychain.values['database_key.fresh'], isNot('1'));
  });

  test('a restore killed after saving the new key and before the wipe wipes at the next start', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    await insertAccount(db);
    await db.close();

    final interrupted = otherKey()..values['database_key.fresh'] = '1';
    final again = await PostinoDatabase.open(path, interrupted);
    expect(await accounts(again), 0);
    await again.close();
    expect(interrupted.values['database_key.fresh'], isNull);
  });

  test('a macOS release opens the database whose key an older version left in the legacy keychain (#270)', () async {
    final legacy = FakeSecureStore();
    final db = await PostinoDatabase.open(path, legacy);
    await insertAccount(db);
    await db.close();

    final dataProtection = FakeSecureStore();
    final again = await PostinoDatabase.open(path, MovingKeychain(dataProtection, legacy));
    expect(await accounts(again), 1);
    await again.close();
    expect(legacy.values, {'database_key.moved': '1'});

    // A Debug build (the legacy keychain alone) finds only the mark: no new key, the file untouched. Another start is
    // a store not seen yet: keyFrom reads once per store.
    final debug = FakeSecureStore()..values.addAll(legacy.values);
    await expectLater(PostinoDatabase.open(path, debug), throwsStateError);
    expect(debug.writes, isEmpty);
    // The Data Protection keychain cannot be read (-34018): the start fails, the file untouched.
    final locked = FakeSecureStore()..failure = Exception('-34018');
    await expectLater(PostinoDatabase.open(path, MovingKeychain(locked, legacy)), throwsException);
    expect(locked.writes, isEmpty);
    final third = await PostinoDatabase.open(path, MovingKeychain(dataProtection, legacy));
    expect(await accounts(third), 1);
    await third.close();

    // Restored on another Mac: the login keychain brings the mark, the Data Protection keychain is empty. Postino
    // starts over empty, as iOS after a restore, and keeps the mark for a Debug build there.
    final restoredLegacy = FakeSecureStore()..values.addAll(legacy.values);
    final restored = FakeSecureStore();
    final fresh = await PostinoDatabase.open(path, MovingKeychain(restored, restoredLegacy));
    expect(await accounts(fresh), 0);
    await fresh.close();
    expect(restored.values.keys, unorderedEquals(['database_key', 'database_key.device_only']));
    expect(restoredLegacy.values, {'database_key.moved': '1'});
  });

  test('a Debug build on the Mac of a release installed new fails, never wipes its database (#270)', () async {
    final legacy = FakeSecureStore();
    final dataProtection = FakeSecureStore();
    final db = await PostinoDatabase.open(path, MovingKeychain(dataProtection, legacy));
    await insertAccount(db);
    await db.close();
    expect(legacy.values, {'database_key.moved': '1'});

    await expectLater(PostinoDatabase.open(path, legacy), throwsStateError);
    final again = await PostinoDatabase.open(path, MovingKeychain(dataProtection, legacy));
    expect(await accounts(again), 1);
    await again.close();
  });

  test('a fresh mark of another key wipes nothing: dropped, the database kept (#270)', () async {
    final keychain = FakeSecureStore();
    final db = await PostinoDatabase.open(path, keychain);
    await insertAccount(db);
    await db.close();

    final again = FakeSecureStore()
      ..values.addAll(keychain.values)
      ..values['database_key.fresh'] = freshOf('ab' * 32);
    final reopened = await PostinoDatabase.open(path, again);
    expect(await accounts(reopened), 1);
    await reopened.close();
    expect(again.values['database_key.fresh'], isNull);
  });

  test('a restore whose new key was killed or read back different before its mark still starts over (#270)', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    await insertAccount(db);
    await db.close();

    // The restored Mac: legacy with only the moved mark; the first start saved the fresh mark and a key that read
    // back different, never marked.
    final legacy = FakeSecureStore()..values['database_key.moved'] = '1';
    final dataProtection = FakeSecureStore()
      ..values.addAll({'database_key.fresh': freshOf('ab' * 32), 'database_key': '${'ab' * 32}!'});
    final again = await PostinoDatabase.open(path, MovingKeychain(dataProtection, legacy));
    expect(await accounts(again), 0, reason: 'a new key, the restored file wiped');
    await again.close();
    expect(dataProtection.values['database_key.device_only'], '1');
  });

  test(
    'a key in the Data Protection keychain always opens its database, whatever the legacy one holds (#270)',
    () async {
      // The release's database, key B in the Data Protection keychain.
      final dataProtection = FakeSecureStore();
      final db = await PostinoDatabase.open(path, MovingKeychain(dataProtection, FakeSecureStore()));
      await insertAccount(db);
      await db.close();
      final before = {...dataProtection.values};
      final writes = dataProtection.writes.length;

      // Legacy {A, device_only, moved}: a downgrade's key, or a login keychain saved then and restored.
      final legacy = FakeSecureStore()
        ..values.addAll({'database_key': 'cd' * 32, 'database_key.device_only': '1', 'database_key.moved': '1'});
      for (var start = 0; start < 2; start++) {
        final again = await PostinoDatabase.open(path, MovingKeychain(dataProtection, legacy));
        expect(await accounts(again), 1);
        await again.close();
      }
      expect(dataProtection.values, before, reason: 'the Data Protection keychain does not change');
      expect(dataProtection.writes, hasLength(writes), reason: 'nothing written there');
      expect(legacy.values['database_key'], 'cd' * 32, reason: 'the legacy key left as it is');
    },
  );

  test(
    'the app and a background engine opening a restore together wipe once, never the database already open',
    () async {
      final db = await PostinoDatabase.open(path, FakeSecureStore());
      await insertAccount(db);
      await db.close();
      _IsolateView.deletes = 0;
      final keychain = otherKey().values..['database_key.fresh'] = '1';
      final views = [_IsolateView(keychain), _IsolateView(keychain, slow: 'database_key.fresh')];
      // Each engine already holds the key (its error log read it): only the mark, the wipe and the open race.
      for (final v in views) {
        await PostinoDatabase.keyFrom(v, path);
      }

      final opening = [for (final v in views) PostinoDatabase.open(path, v)];
      final app = await opening.first;
      await insertAccount(app);
      final background = await opening.last;
      expect(await accounts(background), 1, reason: 'the same database, not a second wipe of it');
      expect(_IsolateView.deletes, 1);
      await app.close();
      await background.close();
    },
  );

  test('the app and a background engine starting with no key create one key, and open the same database', () async {
    final keychain = <String, String>{};
    final opening = [
      PostinoDatabase.open(path, _IsolateView(keychain)),
      PostinoDatabase.open(path, _IsolateView(keychain, slow: 'database_key')),
    ];
    final app = await opening.first;
    await insertAccount(app);
    final background = await opening.last;
    expect(await accounts(background), 1);
    await app.close();
    await background.close();
  });

  test('a background engine migrating an existing database slowly does not hold the lock the app waits for', () async {
    final keychain = FakeSecureStore();
    final db = await PostinoDatabase.open(path, keychain);
    await db.customStatement('PRAGMA user_version = 23'); // one migration to run at the next open
    await db.close();
    final key = keychain.values['database_key']!;
    // Another writer makes the migration wait (busy_timeout), the way a long one (the FTS index rebuilt) keeps going.
    final writer = sqlite3.open(path)
      ..execute("PRAGMA key = \"x'$key'\"")
      ..execute('BEGIN IMMEDIATE');
    final values = {...keychain.values};
    final reachedOpen = ReceivePort();
    final signal = reachedOpen.sendPort;
    final migrating = Isolate.run(() async {
      final background = await PostinoDatabase.open(path, _SignalsFreshRead(signal)..values.addAll(values));
      await background.close();
    });
    // The fresh mark is the last read under the lock: from here the open goes on to the waiting migration.
    await reachedOpen.first;
    try {
      // Locked through the migration, the lock would stay taken until the writer below lets go: well past this.
      expect(await withDatabaseLock('$path.lock', () async => 'free', timeout: const Duration(seconds: 2)), 'free');
    } finally {
      writer.close();
    }
    await migrating;
  });

  test('a database that does not open is in the error log as a crash', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    await db.close();
    final log = EncryptedErrorLog(
      MemoryFileSystem().directory('/logs'),
      logKeysFrom('0f' * 32),
      FakeClock(DateTime.utc(2026, 11, 4)),
    );

    await expectLater(PostinoDatabase.open(path, otherKey(), log: log), throwsA(anything));
    expect(await log.read(), contains('[database]'));
    expect(await log.takeCrashMark(), isTrue);
  });

  test('the key is created once and then read from the keychain only once; a failed read is asked again', () async {
    final keychain = FakeSecureStore()..failure = Exception('keychain bloccato');
    await expectLater(PostinoDatabase.keyFrom(keychain, path), throwsException);

    keychain.failure = null;
    final key = await PostinoDatabase.keyFrom(keychain, path);
    expect(key, hasLength(64));
    keychain.failure = Exception('a second read would prompt again');
    expect(await PostinoDatabase.keyFrom(keychain, path), key);
    expect(await PostinoDatabase.keyFrom(FakeSecureStore()..values.addAll(keychain.values), path), key);
  });

  test('deleted content is overwritten (secure_delete)', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    final row = await db.customSelect('PRAGMA secure_delete').getSingle();
    expect(row.data.values.single, 1);
    await db.close();
  });
}
