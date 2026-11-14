import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3 show Database;

// The generated part maps enum columns to these types.
import '../domain/account.dart';
import '../domain/draft_content.dart';
import '../domain/error_log.dart';
import '../domain/mailbox.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';
import 'account_settings_json.dart';
import 'attachment_crypto.dart';
import 'daos/accounts_dao.dart';
import 'daos/attributes_dao.dart';
import 'daos/bodies_dao.dart';
import 'daos/conflicts_dao.dart';
import 'daos/contacts_dao.dart';
import 'daos/device_settings_dao.dart';
import 'daos/drafts_dao.dart';
import 'daos/intents_dao.dart';
import 'daos/labels_dao.dart';
import 'daos/message_embeddings_dao.dart';
import 'daos/messages_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/postino_settings_dao.dart';
import 'daos/search_dao.dart';
import 'daos/trusted_senders_dao.dart';
import 'database_lock.dart';
import 'device_only_key.dart';
import 'row_mappers.dart';
import 'search_index.dart';
import 'tables/accounts_table.dart';
import 'tables/bodies_table.dart';
import 'tables/conflicts_table.dart';
import 'tables/device_settings_table.dart';
import 'tables/drafts_table.dart';
import 'tables/intents_table.dart';
import 'tables/labels_table.dart';
import 'tables/message_embeddings_table.dart';
import 'tables/message_labels_table.dart';
import 'tables/messages_table.dart';
import 'tables/outbox_table.dart';
import 'tables/postino_settings_table.dart';
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
    Conflicts,
    TrustedSenders,
    DeviceSettings,
    Drafts,
    Outbox,
    PostinoSettings,
    MessageEmbeddings,
  ],
  daos: [
    AccountsDao,
    MessagesDao,
    LabelsDao,
    BodiesDao,
    IntentsDao,
    AttributesDao,
    ConflictsDao,
    TrustedSendersDao,
    DeviceSettingsDao,
    DraftsDao,
    OutboxDao,
    PostinoSettingsDao,
    MessageEmbeddingsDao,
    SearchDao,
    ContactsDao,
  ],
)
class PostinoDatabase(super.e) extends _$PostinoDatabase {
  /// Host tests: same schema, plain SQLite, no key. Streams close synchronously: drift's close timer would outlive widget tests.
  factory PostinoDatabase.inMemory() =>
      PostinoDatabase(DatabaseConnection(NativeDatabase.memory(setup: _secureDelete), closeStreamsSynchronously: true));

  /// On device: SQLCipher file, key generated at first launch and kept in the [keychain].
  /// A file that does not open (damaged, wrong key) is a crash for [log] before it propagates (#116): Postino cannot
  /// start, and the next start proposes the Segnalazione di un problema.
  static Future<PostinoDatabase> open(String path, SecureStore keychain, {ErrorLog? log}) async {
    final key = await keyFrom(keychain, path);
    // Locked from the mark to its removal, and to the creation of a new file: the mark read before another isolate's
    // wipe would wipe a database already open. An existing file opens unlocked: its migrations may be long (#263).
    final created = await withDatabaseLock(_lockOf(path), () async {
      // A file older than its key (a backup restored on another device: the key stays on the first one, #263) can
      // never be read: Postino starts over empty and syncs again. The mark outlives a start killed before the wipe.
      // A mark of another key is stale, left by a start killed before a downgrade made this key (#270): dropped.
      if (await keychain.read(_freshName) case final fresh?) {
        if (isFreshOf(fresh, key)) {
          for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
            if (File(f).existsSync()) File(f).deleteSync();
          }
        }
        await keychain.delete(_freshName);
      }
      if (File(path).existsSync()) return null;
      // A new file is this key's: a key kept for an older one (#270) opens nothing any more.
      if (await keychain.read(_replacedName) != null) await _dropReplaced(keychain);
      return _openFile(path, key, log);
    });
    if (created != null) return created;
    // A downgrade's key moved over one in use (#270): the file tells which of the two is its key; the other goes.
    final replaced = await keychain.read(_replacedName);
    if (replaced == null || replaced == key) {
      final db = await _openFile(path, key, log);
      if (replaced != null) await _dropReplaced(keychain);
      return db;
    }
    final PostinoDatabase db;
    try {
      db = await _openFile(path, key, null);
    } on Object catch (e, s) {
      final PostinoDatabase kept;
      try {
        kept = await _openFile(path, replaced, null);
      } on Object catch (_) {
        // Neither opens: the error of the key in use is the one to report.
        log?.record(e, stack: s, context: 'database', crash: true);
        Error.throwWithStackTrace(e, s);
      }
      try {
        // The kept key leaves its slot only once it is the key again: an overwrite that fails half way (the item
        // deleted, not added) leaves it there, and the next start puts it back ([readDeviceOnly]).
        await withDatabaseLock(_lockOf(path), () async {
          await writeDeviceOnly(keychain, _keyName, replaced);
          await keychain.delete(_replacedName);
        });
        // ponytail: silent, the database is open with the right key; the next start tries again.
      } on Object catch (_) {}
      // ponytail: this start's error log keeps the keys of the losing key, so its entries are unreadable later.
      _keys[keychain] = Future.value(replaced);
      return kept;
    }
    await _dropReplaced(keychain);
    return db;
  }

  /// Forgets the key a moved one replaced (#270), once the database opened without it.
  static Future<void> _dropReplaced(SecureStore keychain) async {
    try {
      await keychain.delete(_replacedName);
      // ponytail: silent, the database is open; the next start drops it again.
    } on Object catch (_) {}
  }

  static Future<PostinoDatabase> _openFile(String path, String key, ErrorLog? log) async {
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
          // The WorkManager isolate opens the same file (#36): a write waits for the other's lock instead of failing.
          sql.execute('PRAGMA busy_timeout = 5000');
        },
      ),
    );
    try {
      await db.customSelect('SELECT 1').get(); // open now, not on first query
      return db;
    } catch (e, s) {
      log?.record(e, stack: s, context: 'database', crash: true);
      await db.close();
      rethrow;
    }
  }

  /// The database file in the app's support [dir].
  static String fileIn(String dir) => '$dir/postino.db';

  /// The database key (hex) from the [keychain], generated and saved at the first launch; the error log's keys
  /// derive from it too (#116). Read once per [keychain]: each read may be a system prompt (#76).
  /// A failed read is not remembered: the next call asks again. Read, migrated or created under the lock of the
  /// database at [path]: another isolate starting meanwhile reads the key this one wrote, never a second one.
  static Future<String> keyFrom(SecureStore keychain, String path) async {
    try {
      return await (_keys[keychain] ??= withDatabaseLock(_lockOf(path), () => _readOrCreateKey(keychain)));
    } on Object catch (_) {
      _keys[keychain] = null;
      rethrow;
    }
  }

  static final _keys = Expando<Future<String>>();

  static Future<String> _readOrCreateKey(SecureStore keychain) async {
    if (await readDeviceOnly(keychain, _keyName) case final key?) return key;
    final key = hex(randomBytes(32));
    // Before the key: a new key means no file it can open, which [open] wipes.
    await keychain.write(_freshName, freshOf(key));
    await writeDeviceOnly(keychain, _keyName, key);
    return key;
  }

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Not a drift table: the full-text index and its triggers (#205).
      await createSearchIndex(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(bodies);
        await m.createTable(syncCursors);
      }
      if (from < 3) {
        // Only user labels are Etichette: drop the Gmail system ones cached as such by v1-v2 syncs.
        await customStatement(
          "DELETE FROM labels WHERE id IN ('INBOX','SENT','DRAFT','SPAM','TRASH', "
          "'STARRED','UNREAD','IMPORTANT','CHAT') OR id LIKE 'CATEGORY\\_%' ESCAPE '\\'",
        );
      }
      if (from < 4) {
        // Account color: its place in the palette instead of the light-theme ARGB, so dark mode has its own.
        final cases = [for (final (i, argb) in _v3AccountColors.indexed) 'WHEN $argb THEN $i'].join(' ');
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
        // The queue is created by the v18 step, in its current shape.
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
      if (from < 12) {
        // Reply-To and References of the messages, the threading headers and the forwarded attachments of the
        // Bozze (#37); the cached messages keep null until synced again.
        await m.addColumn(messages, messages.replyTo);
        await m.addColumn(messages, messages.references);
        // Before v10 the drafts table was just created above, already with them.
        if (from >= 10) {
          await m.addColumn(drafts, drafts.inReplyTo);
          await m.addColumn(drafts, drafts.references);
          await m.addColumn(drafts, drafts.conversationId);
          await m.addColumn(drafts, drafts.attachments);
        }
      }
      if (from < 13) await m.createTable(outbox);
      if (from < 15) await m.createTable(postinoSettings);
      // From v14 the table was just created above, already with them.
      if (from == 15) {
        // The voci written before the sync are still to upload, but older than any copy elsewhere (updatedAt 0):
        // a device migrating later must never overwrite what another device already synced.
        // ponytail: no device id for them yet; the next write of the voce stamps it.
        await m.alterTable(
          TableMigration(
            postinoSettings,
            newColumns: [
              postinoSettings.updatedAt,
              postinoSettings.deviceId,
              postinoSettings.deleted,
              postinoSettings.dirty,
            ],
            columnTransformer: {
              postinoSettings.updatedAt: const Constant(0),
              postinoSettings.deviceId: const Constant(''),
              postinoSettings.dirty: const Constant(true),
            },
          ),
        );
      }
      if (from < 17) await m.createTable(messageEmbeddings);
      if (from < 18) await _queueOfAzioni(m);
      // The expected value and the Conflitto of the Bozze (#149); before v10 the table was just created above, with them.
      if (from >= 10 && from < 19) {
        await m.addColumn(drafts, drafts.expected);
        await m.addColumn(drafts, drafts.conflict);
      }
      // Before v18 the queue was just created above, with it; a database taken back to v18 or v19 may hold it already.
      // Up to v21: a v20 of the #142 branch (the Account voci) came before this column, and lacks it.
      if (from >= 18 && from < 22 && !await _hasColumn('intents', 'rfc_message_id')) {
        await m.addColumn(intents, intents.rfcMessageId);
      }
      // Before v13 the outbox was just created above, with it.
      if (from >= 13 && from < 21 && !await _hasColumn('outbox', 'smtp_sent_at')) {
        await m.addColumn(outbox, outbox.smtpSentAt);
      }
      if (from < 24) {
        // v24: the Accounts already here join the synced voci (ADR 0016) as the voci written before the sync did:
        // to upload, but older than any copy elsewhere (updatedAt 0), so they never overwrite a synced one.
        for (final r in await select(accounts).get()) {
          await into(postinoSettings).insert(
            PostinoSettingsCompanion.insert(
              key: accountSettingsKey(r.id),
              value: Value(encodeAccountSettings(accountOf(r))),
              updatedAt: 0,
              deviceId: '',
              dirty: true,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
      if (from < 7) {
        await m.addColumn(messages, messages.senderName);
        await m.addColumn(messages, messages.cc);
        // v1-v6 kept the raw From header and comma-joined To: split into address and name, one recipient per line.
        final rows = await customSelect('SELECT account_id, id, sender, recipients FROM messages').get();
        for (final r in rows) {
          final from = parseMailbox(r.read<String>('sender'));
          await customUpdate(
            'UPDATE messages SET sender = ?, sender_name = ?, recipients = ? '
            'WHERE account_id = ? AND id = ?',
            variables: [
              Variable(from.address),
              Variable(from.name),
              Variable([for (final m in parseMailboxes(r.read<String>('recipients'))) formatMailbox(m)].join('\n')),
              Variable(r.read<String>('account_id')),
              Variable(r.read<String>('id')),
            ],
          );
        }
      }
      // v23: whether a message has attachments, unknown (null) for the rows already stored (#206).
      if (from < 23 && !await _hasColumn('messages', 'has_attachments')) {
        await m.addColumn(messages, messages.hasAttachments);
        // What the bodies stored already know (before v9 they kept no attachments).
        if (await _hasColumn('bodies', 'attachments')) {
          await customStatement(
            'UPDATE messages SET has_attachments = json_array_length(b.attachments) > 0 FROM bodies b '
            'WHERE b.account_id = messages.account_id AND b.message_id = messages.id AND b.attachments IS NOT NULL',
          );
        }
      }
      // Last: it reads the columns of every step above (v7 split the sender). By name too: a v22 of the #142 branch
      // (the Account voci) came before it, and lacks it.
      if (from < 22 || !await _hasColumn('search_index', 'subject')) await createSearchIndex(this);
    },
  );

  Future<bool> _hasColumn(String table, String column) async =>
      (await customSelect('PRAGMA table_info($table)').get()).any((r) => r.read<String>('name') == column);

  /// v18: one queue of Azioni with the expected value, and the Conflitti (#144). The read intents (v5) and the
  /// Etichette ones (v14) move into it; their value at enqueue was not kept, so the expected one is the opposite of
  /// the wanted one: what the old replay assumed, an attribute that is on or off never meeting a Conflitto.
  Future<void> _queueOfAzioni(Migrator m) async {
    // By name, not by version: a database is what its file holds.
    final old = {
      for (final r in await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('intents', 'label_intents')",
      ).get())
        r.read<String>('name'),
    };
    if (old.contains('intents')) await customStatement('ALTER TABLE intents RENAME TO intents_v17');
    await m.createTable(intents);
    await m.createTable(conflicts);
    if (old.contains('intents')) {
      await customStatement(
        'INSERT INTO intents (account_id, message_id, attribute, wanted, expected) '
        "SELECT account_id, message_id, 'read', CASE is_read WHEN 1 THEN 'true' ELSE 'false' END, "
        "CASE is_read WHEN 1 THEN 'false' ELSE 'true' END FROM intents_v17 WHERE is_read IS NOT NULL",
      );
      await customStatement('DROP TABLE intents_v17');
    }
    if (old.contains('label_intents')) {
      await customStatement(
        'INSERT INTO intents (account_id, message_id, attribute, wanted, expected) '
        "SELECT account_id, message_id, 'label:' || label_id, CASE added WHEN 1 THEN 'true' ELSE 'false' END, "
        "CASE added WHEN 1 THEN 'false' ELSE 'true' END FROM label_intents",
      );
      await customStatement('DROP TABLE label_intents');
    }
  }
}

void _secureDelete(sqlite3.Database sql) => sql.execute('PRAGMA secure_delete = ON');

const _keyName = 'database_key';
final _freshName = freshMark(_keyName);
final _replacedName = replacedMark(_keyName);

/// Never wiped with the database: it outlives the restore it guards.
String _lockOf(String path) => '$path.lock';

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
