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

  Future<void> insertAccount(PostinoDatabase db) => db.customStatement(
    "INSERT INTO accounts VALUES ('a1', 'a@example.com', 'gmail', 1, 0, 'attivo')",
  );
  Future<int> accounts(PostinoDatabase db) async =>
      (await db.customSelect('SELECT count(*) AS n FROM accounts').getSingle())
          .read<int>('n');

  test(
    'the file is encrypted and reopens with the key kept in the keychain',
    () async {
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
    },
  );

  test('without the keychain key the file cannot be read', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    await insertAccount(db);
    await db.close();

    expect(
      () => PostinoDatabase.open(path, FakeSecureStore()),
      throwsA(anything),
    );
  });

  test('deleted content is overwritten (secure_delete)', () async {
    final db = await PostinoDatabase.open(path, FakeSecureStore());
    final row = await db.customSelect('PRAGMA secure_delete').getSingle();
    expect(row.data.values.single, 1);
    await db.close();
  });
}
