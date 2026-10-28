import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3 show Database;

import '../domain/account.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';

part 'postino_database.g.dart';

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get address => text()();
  TextColumn get provider => textEnum<ProviderKind>()();
  IntColumn get color => integer()();
  IntColumn get position => integer()();
  TextColumn get status => textEnum<AccountStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LabelRow')
class Labels extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<LabelKind>()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();
  TextColumn get sender => text()();
  TextColumn get recipients => text()();
  TextColumn get subject => text()();
  TextColumn get snippet => text()();

  /// Milliseconds since epoch, UTC.
  IntColumn get date => integer()();
  BoolColumn get isRead => boolean()();
  BoolColumn get isStarred => boolean()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

@DataClassName('MessageLabelRow')
class MessageLabels extends Table {
  TextColumn get accountId => text()();
  TextColumn get messageId => text()();
  TextColumn get labelId => text()();

  @override
  Set<Column> get primaryKey => {accountId, messageId, labelId};
}

/// Single local database (ADR 0003). The UI reads only from here; the sync engine writes.
@DriftDatabase(tables: [Accounts, Labels, Messages, MessageLabels])
class PostinoDatabase extends _$PostinoDatabase {
  PostinoDatabase(super.executor);

  /// Host tests: same schema, plain SQLite, no key. Streams close synchronously: drift's close timer would outlive widget tests.
  factory PostinoDatabase.inMemory() => PostinoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(setup: _secureDelete),
      closeStreamsSynchronously: true,
    ),
  );

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
    final db = PostinoDatabase(
      NativeDatabase(
        File(path),
        // Throwing here makes drift close the native handle (wrong key, no SQLCipher).
        setup: (sql) {
          sql.execute("PRAGMA key = \"x'$key'\"");
          if (sql.select('PRAGMA cipher_version').isEmpty) {
            throw StateError('SQLite without SQLCipher: refusing to open');
          }
          // A wrong key fails here.
          sql.select('SELECT count(*) FROM sqlite_master');
          _secureDelete(sql);
        },
      ),
    );
    try {
      await db.customSelect('SELECT 1').get(); // open now, not on first query
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

void _secureDelete(sqlite3.Database sql) =>
    sql.execute('PRAGMA secure_delete = ON');

const _keyName = 'database_key';
