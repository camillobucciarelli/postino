// Rimozione di un Account (#174), on the database: every row of the Account goes, the other Account's stay.

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';

/// The tables holding a row per Account, by their `account_id` (or `id` for the Accounts): found from the schema,
/// so a table added later without its `deleteByAccount` fails here.
Future<Map<String, String>> _accountTables(PostinoDatabase db) async {
  final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
  return {
    for (final t in tables.map((r) => r.read<String>('name')))
      for (final c in await db.customSelect('PRAGMA table_info("$t")').get())
        if (c.read<String>('name') == 'account_id' || (t == 'accounts' && c.read<String>('name') == 'id'))
          t: c.read<String>('name'),
  };
}

/// One row of [table] for [account], every NOT NULL column filled with a placeholder of its type.
Future<void> _insertRow(PostinoDatabase db, String table, String column, String account) async {
  final columns = await db.customSelect('PRAGMA table_info("$table")').get();
  final names = <String>[];
  final values = <Variable<Object>>[];
  for (final c in columns) {
    final name = c.read<String>('name');
    if (name != column && c.read<int>('notnull') == 0) continue;
    names.add('"$name"');
    final type = c.read<String>('type').toUpperCase();
    values.add(
      name == column
          ? Variable<String>(account)
          : type.contains('INT')
          ? const Variable<int>(0)
          : type.contains('BLOB')
          ? Variable<Uint8List>(Uint8List(4))
          : const Variable<String>('x'),
    );
  }
  await db.customInsert(
    'INSERT INTO "$table" (${names.join(', ')}) VALUES (${List.filled(names.length, '?').join(', ')})',
    variables: values,
  );
}

Future<int> _count(PostinoDatabase db, String table, String column, String account) async =>
    (await db
            .customSelect(
              'SELECT count(*) AS n FROM "$table" WHERE "$column" = ?',
              variables: [Variable<String>(account)],
            )
            .getSingle())
        .read<int>('n');

void main() {
  test('removing an Account deletes its rows in every table and keeps the other Account intact', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    final tables = await _accountTables(db);
    expect(
      tables.keys,
      containsAll(['accounts', 'messages', 'labels', 'bodies', 'drafts', 'intents', 'conflicts', 'outbox']),
    );
    for (final MapEntry(key: table, value: column) in tables.entries) {
      for (final account in ['gmail:ada@gmail.com', 'gmail:bob@gmail.com']) {
        await _insertRow(db, table, column, account);
      }
    }

    await MailStore(db).removeAccount('gmail:ada@gmail.com');

    for (final MapEntry(key: table, value: column) in tables.entries) {
      expect(await _count(db, table, column, 'gmail:ada@gmail.com'), 0, reason: '$table of the removed Account');
      expect(await _count(db, table, column, 'gmail:bob@gmail.com'), 1, reason: '$table of the other Account');
    }
  });
}
