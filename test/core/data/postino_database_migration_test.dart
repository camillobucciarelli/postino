import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('v3 drops the Gmail system labels cached as Etichette, keeping user ones', () async {
    final raw = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE labels (account_id TEXT NOT NULL, id TEXT NOT NULL, '
        'name TEXT NOT NULL, kind TEXT NOT NULL, PRIMARY KEY (account_id, id))',
      )
      ..execute('PRAGMA user_version = 2');
    for (final id in ['INBOX', 'STARRED', 'CATEGORY_PERSONAL', 'Label_12']) {
      raw.execute(
        "INSERT INTO labels VALUES ('a1', '$id', '$id', 'etichetta')",
      );
    }
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final ids = await db.select(db.labels).map((l) => l.id).get();
    expect(ids, ['Label_12']);
  });
}
