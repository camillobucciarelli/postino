import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/error_log/encrypted_error_log.dart';
import 'package:postino/core/data/error_log/log_keys.dart';
import 'package:postino/core/data/postino_database.dart';

import '../../support/fake_platform.dart';

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
    await again.close();
    expect(await accounts(await PostinoDatabase.open(path, restored)), 0, reason: 'reopens with the new key');
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
    await expectLater(PostinoDatabase.keyFrom(keychain), throwsException);

    keychain.failure = null;
    final key = await PostinoDatabase.keyFrom(keychain);
    expect(key, hasLength(64));
    keychain.failure = Exception('a second read would prompt again');
    expect(await PostinoDatabase.keyFrom(keychain), key);
    expect(await PostinoDatabase.keyFrom(FakeSecureStore()..values.addAll(keychain.values)), key);
  });

  test('deleted content is overwritten (secure_delete)', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    final row = await db.customSelect('PRAGMA secure_delete').getSingle();
    expect(row.data.values.single, 1);
    await db.close();
  });
}
