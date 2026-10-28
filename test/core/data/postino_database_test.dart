import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  void insertAccount(PostinoDatabase db) => db.sql.execute(
    "INSERT INTO accounts VALUES ('a1', 'a@example.com', 'gmail', 1, 0, 'attivo')",
  );
  int accounts(PostinoDatabase db) =>
      db.sql.select('SELECT count(*) AS n FROM accounts').first['n'] as int;

  test(
    'the file is encrypted and reopens with the key kept in the keychain',
    () async {
      final keychain = FakeSecureStore();
      final db = await PostinoDatabase.open(path, keychain);
      insertAccount(db);
      db.sql.close();

      expect(
        File(path).readAsBytesSync().sublist(0, 15),
        isNot('SQLite format 3'.codeUnits),
        reason: 'a plain SQLite file starts with its magic header',
      );
      final again = await PostinoDatabase.open(path, keychain);
      expect(accounts(again), 1);
    },
  );

  test('without the keychain key the file cannot be read', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    insertAccount(db);
    db.sql.close();

    expect(
      () => PostinoDatabase.open(path, FakeSecureStore()),
      throwsA(anything),
    );
  });

  test('deleted content is overwritten (secure_delete)', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    expect(db.sql.select('PRAGMA secure_delete').first.values.first, 1);
  });
}
