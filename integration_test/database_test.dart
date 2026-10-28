// Run on an iOS simulator and an Android emulator: real keychain + real SQLCipher.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:postino/core/data/platform_services.dart';
import 'package:postino/core/data/postino_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the database is encrypted and its key survives in the keychain',
    (tester) async {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/it_postino.db';
      for (final f in [File(path), File('$path-journal')]) {
        if (f.existsSync()) f.deleteSync();
      }
      final keychain = KeychainStore();

      final db = await PostinoDatabase.open(path, keychain);
      db.sql.execute(
        "INSERT INTO accounts VALUES ('a1', 'a@example.com', 'gmail', 1, 0, 'attivo')",
      );
      db.sql.close();

      expect(
        File(path).readAsBytesSync().sublist(0, 15),
        isNot('SQLite format 3'.codeUnits),
      );
      final again = await PostinoDatabase.open(path, keychain);
      expect(
        again.sql.select('SELECT count(*) AS n FROM accounts').first['n'],
        1,
      );
    },
  );
}
