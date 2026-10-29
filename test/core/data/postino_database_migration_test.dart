import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:sqlite3/sqlite3.dart';

const _v3Accounts =
    'CREATE TABLE accounts (id TEXT NOT NULL PRIMARY KEY, address TEXT NOT NULL, '
    'provider TEXT NOT NULL, color INTEGER NOT NULL, position INTEGER NOT NULL, '
    'status TEXT NOT NULL)';

void main() {
  test('v3 drops the Gmail system labels cached as Etichette, keeping user ones', () async {
    final raw = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE labels (account_id TEXT NOT NULL, id TEXT NOT NULL, '
        'name TEXT NOT NULL, kind TEXT NOT NULL, PRIMARY KEY (account_id, id))',
      )
      ..execute(_v3Accounts)
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

  test('v4 stores the Account color as its place in the palette', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute('PRAGMA user_version = 3');
    // sky, olive, and a color no version ever assigned (falls back to the position).
    for (final (id, argb, position) in [
      ('a1', 0xFF00779E, 0),
      ('a2', 0xFF6B6F00, 1),
      ('a3', 0xFF123456, 10),
    ]) {
      raw.execute(
        "INSERT INTO accounts VALUES ('$id', '$id@example.com', 'gmail', $argb, $position, 'attivo')",
      );
    }
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final colors = {
      for (final a in await db.select(db.accounts).get()) a.id: a.color,
    };
    expect(colors, {'a1': 0, 'a2': 5, 'a3': 2});
  });
}
