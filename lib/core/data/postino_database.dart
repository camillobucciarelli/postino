import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../domain/platform_services.dart';

/// Single local database (ADR 0003). The UI reads only from here; the sync engine writes.
class PostinoDatabase {
  PostinoDatabase(this.sql) {
    sql
      ..execute('PRAGMA secure_delete = ON')
      ..execute(_schema);
  }

  /// Host tests: same schema, plain SQLite, no key.
  factory PostinoDatabase.inMemory() => PostinoDatabase(sqlite3.openInMemory());

  /// On device: SQLCipher file, key generated at first launch and kept in the [keychain].
  static Future<PostinoDatabase> open(String path, SecureStore keychain) async {
    var key = await keychain.read(_keyName);
    if (key == null) {
      final random = Random.secure();
      key = [
        for (var i = 0; i < 32; i++)
          random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join();
      await keychain.write(_keyName, key);
    }
    final sql = sqlite3.open(path);
    try {
      sql.execute("PRAGMA key = \"x'$key'\"");
      return PostinoDatabase(sql);
    } catch (_) {
      sql.close(); // don't leak the native handle on a wrong key
      rethrow;
    }
  }

  final Database sql;
}

const _keyName = 'database_key';

const _schema = '''
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY, address TEXT NOT NULL, provider TEXT NOT NULL,
  color INTEGER NOT NULL, position INTEGER NOT NULL, status TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS labels (
  account_id TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL,
  PRIMARY KEY (account_id, id)
);
CREATE TABLE IF NOT EXISTS messages (
  account_id TEXT NOT NULL, id TEXT NOT NULL, message_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL, sender TEXT NOT NULL, recipients TEXT NOT NULL,
  subject TEXT NOT NULL, snippet TEXT NOT NULL, date INTEGER NOT NULL,
  is_read INTEGER NOT NULL, is_starred INTEGER NOT NULL,
  PRIMARY KEY (account_id, id)
);
CREATE TABLE IF NOT EXISTS message_labels (
  account_id TEXT NOT NULL, message_id TEXT NOT NULL, label_id TEXT NOT NULL,
  PRIMARY KEY (account_id, message_id, label_id)
);
''';
