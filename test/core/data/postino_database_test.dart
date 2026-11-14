import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/error_log/encrypted_error_log.dart';
import 'package:postino/core/data/error_log/log_keys.dart';
import 'package:postino/core/data/postino_database.dart';

import 'package:postino/core/domain/platform_services.dart';

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
