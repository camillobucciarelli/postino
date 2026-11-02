import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3 show Database;

// The generated part maps enum columns to these types.
import '../domain/account.dart';
import '../domain/mailbox.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';
import 'daos/accounts_dao.dart';
import 'daos/device_settings_dao.dart';
import 'daos/drafts_dao.dart';
import 'daos/intents_dao.dart';
import 'daos/messages_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/trusted_senders_dao.dart';
import 'tables/accounts_table.dart';
import 'tables/bodies_table.dart';
import 'tables/device_settings_table.dart';
import 'tables/drafts_table.dart';
import 'tables/intents_table.dart';
import 'tables/labels_table.dart';
import 'tables/message_labels_table.dart';
import 'tables/messages_table.dart';
import 'tables/outbox_table.dart';
import 'tables/sync_cursors_table.dart';
import 'tables/trusted_senders_table.dart';

part 'postino_database.g.dart';

/// Single local database (ADR 0003). The UI reads only from here; the sync engine writes.
@DriftDatabase(
  tables: [
    Accounts,
    Labels,
    Messages,
    MessageLabels,
    Bodies,
    SyncCursors,
    Intents,
    TrustedSenders,
    DeviceSettings,
    Drafts,
    Outbox,
  ],
  daos: [
    AccountsDao,
    MessagesDao,
    IntentsDao,
    TrustedSendersDao,
    DeviceSettingsDao,
    DraftsDao,
    OutboxDao,
  ],
)
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
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(bodies);
        await m.createTable(syncCursors);
      }
      if (from < 3) {
        // Only user labels are Etichette: drop the Gmail system ones cached as such by v1-v2 syncs.
        await customStatement(
          "DELETE FROM labels WHERE id IN ('INBOX','SENT','DRAFT','SPAM','TRASH',"
          "'STARRED','UNREAD','IMPORTANT','CHAT') OR id LIKE 'CATEGORY\\_%' ESCAPE '\\'",
        );
      }
      if (from < 4) {
        // Account color: its place in the palette instead of the light-theme ARGB, so dark mode has its own.
        final cases = [
          for (final (i, argb) in _v3AccountColors.indexed)
            'WHEN $argb THEN $i',
        ].join(' ');
        await customStatement(
          'UPDATE accounts SET color = CASE color $cases '
          'ELSE position % $accountColorCount END',
        );
      }
      if (from < 5) {
        // From v1 the bodies table was just created above, already with its kind.
        if (from >= 2) {
          await m.addColumn(bodies, bodies.kind);
          // v2-v4 kept the HTML part when there was one, without saying so.
          // ponytail: tag sniffing; a plain text body quoting HTML reads as HTML until it is downloaded again.
          await customStatement(
            "UPDATE bodies SET kind = 'html' WHERE body LIKE '%</%' "
            "OR body LIKE '%<br>%' OR body LIKE '%<br/%' OR body LIKE '%<br /%'",
          );
        }
        await m.createTable(intents);
        await m.createIndex(messagesConversation);
      }
      if (from < 6) await m.createTable(trustedSenders);
      // From v1 the bodies table was just created above, already with it.
      if (from >= 2 && from < 9) await m.addColumn(bodies, bodies.attachments);
      if (from < 8) await m.createTable(deviceSettings);
      if (from < 10) {
        await m.createTable(drafts);
        await m.addColumn(messages, messages.bcc);
        // Cached Bozze got an empty Bcc, though on the Provider they may have one: with the cursors gone the
        // next sync is a full one and brings it (openDraft reads the recipients from the cached message).
        await customStatement('DELETE FROM sync_cursors');
      }
      if (from < 11) await m.createTable(outbox);
      if (from < 7) {
        await m.addColumn(messages, messages.senderName);
        await m.addColumn(messages, messages.cc);
        // v1-v6 kept the raw From header and comma-joined To: split into address and name, one recipient per line.
        final rows = await customSelect(
          'SELECT account_id, id, sender, recipients FROM messages',
        ).get();
        for (final r in rows) {
          final from = parseMailbox(r.read<String>('sender'));
          await customUpdate(
            'UPDATE messages SET sender = ?, sender_name = ?, recipients = ? '
            'WHERE account_id = ? AND id = ?',
            variables: [
              Variable(from.address),
              Variable(from.name),
              Variable(
                [
                  for (final m in parseMailboxes(r.read<String>('recipients')))
                    formatMailbox(m),
                ].join('\n'),
              ),
              Variable(r.read<String>('account_id')),
              Variable(r.read<String>('id')),
            ],
          );
        }
      }
    },
  );
}

void _secureDelete(sqlite3.Database sql) =>
    sql.execute('PRAGMA secure_delete = ON');

const _keyName = 'database_key';

/// The light-theme ARGB colors v1-v3 stored, in palette order (sky … graphite).
const _v3AccountColors = [
  0xFF00779E,
  0xFF3559C3,
  0xFF6C3FAF,
  0xFF95388B,
  0xFFB43C6B,
  0xFF6B6F00,
  0xFF445465,
  0xFF403D36,
];
