import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/fake_mail_provider.dart';

/// The v2-v4 bodies table, before it said HTML or text.
const _v4Bodies =
    'CREATE TABLE bodies (account_id TEXT NOT NULL, message_id TEXT NOT NULL, '
    'body TEXT NOT NULL, PRIMARY KEY (account_id, message_id))';

const _v4Messages =
    'CREATE TABLE messages (account_id TEXT NOT NULL, id TEXT NOT NULL, message_id TEXT NOT NULL, '
    'conversation_id TEXT NOT NULL, sender TEXT NOT NULL, recipients TEXT NOT NULL, '
    'subject TEXT NOT NULL, snippet TEXT NOT NULL, date INTEGER NOT NULL, '
    'is_read INTEGER NOT NULL, is_starred INTEGER NOT NULL, PRIMARY KEY (account_id, id))';

const _v3Accounts =
    'CREATE TABLE accounts (id TEXT NOT NULL PRIMARY KEY, address TEXT NOT NULL, '
    'provider TEXT NOT NULL, color INTEGER NOT NULL, position INTEGER NOT NULL, '
    'status TEXT NOT NULL)';

/// Exists since v1; the v10 migration empties it.
const _syncCursors = 'CREATE TABLE sync_cursors (account_id TEXT NOT NULL PRIMARY KEY, cursor TEXT NOT NULL)';

/// The v5-v17 read queue, one column per attribute.
const _v17Intents =
    'CREATE TABLE intents (account_id TEXT NOT NULL, message_id TEXT NOT NULL, is_read INTEGER NULL, '
    'PRIMARY KEY (account_id, message_id))';

/// The v14-v17 Etichette queue.
const _v17LabelIntents =
    'CREATE TABLE label_intents (account_id TEXT NOT NULL, message_id TEXT NOT NULL, label_id TEXT NOT NULL, '
    'added INTEGER NOT NULL, PRIMARY KEY (account_id, message_id, label_id))';

/// Takes the Bozze of a current database back to their v18 shape: no expected value, no Conflitto.
Database _backToV18(Database raw) => raw
  ..execute('ALTER TABLE drafts DROP COLUMN expected')
  ..execute('ALTER TABLE drafts DROP COLUMN conflict');

/// Takes the queue of a current database back to its v17 shape: two queues, no Conflitti.
void _backToV17(Database raw) => _backToV18(raw)
  ..execute('DROP TABLE conflicts')
  ..execute('DROP TABLE intents')
  ..execute(_v17Intents)
  ..execute(_v17LabelIntents);

void main() {
  test('v19 adds the expected value and the Conflitto of the Bozze, null for those stored before', () async {
    final raw = sqlite3.openInMemory();
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV18(raw);
    raw
      ..execute(
        "INSERT INTO drafts (account_id, message_id, recipients, cc, bcc, subject, body, updated_at, pending, synced, "
        "remote_known) VALUES ('a1', '<x>', 'b@example.com', '', '', 's', '<p>Ciao</p>', 7, 1, 1, 1)",
      )
      ..execute('PRAGMA user_version = 18');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final d = await db.select(db.drafts).getSingle();
    expect((d.messageId, d.pending, d.expected, d.conflict), ('<x>', true, null, null));
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test('v18 moves the read and Etichette queues into the queue of Azioni, expecting the opposite value', () async {
    final raw = sqlite3.openInMemory();
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV17(raw);
    raw
      ..execute("INSERT INTO intents VALUES ('a1', 'm1', 1)")
      ..execute("INSERT INTO intents VALUES ('a1', 'm2', 0)")
      ..execute("INSERT INTO intents VALUES ('a1', 'm3', NULL)")
      ..execute("INSERT INTO label_intents VALUES ('a1', 'm1', 'Label_12', 1)")
      ..execute("INSERT INTO label_intents VALUES ('a1', 'm2', 'Label_7', 0)")
      ..execute('PRAGMA user_version = 17');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final rows = await db.intentsDao.pending('a1', now: 0);
    expect(
      {for (final r in rows) (r.messageId, r.attribute, r.wanted, r.expected, r.heldUntil)},
      {
        ('m1', 'read', 'true', 'false', null),
        ('m2', 'read', 'false', 'true', null),
        ('m1', 'label:Label_12', 'true', 'false', null),
        ('m2', 'label:Label_7', 'false', 'true', null),
      },
    );
    expect(await db.select(db.conflicts).get(), isEmpty);
    expect(raw.select("SELECT name FROM sqlite_master WHERE name IN ('label_intents', 'intents_v17')"), isEmpty);
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test('v3 drops the Gmail system labels cached as Etichette, keeping user ones', () async {
    final raw = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE labels (account_id TEXT NOT NULL, id TEXT NOT NULL, '
        'name TEXT NOT NULL, kind TEXT NOT NULL, PRIMARY KEY (account_id, id))',
      )
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute('PRAGMA user_version = 2');
    for (final id in ['INBOX', 'STARRED', 'CATEGORY_PERSONAL', 'Label_12']) {
      raw.execute("INSERT INTO labels VALUES ('a1', '$id', '$id', 'etichetta')");
    }
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final ids = await db.select(db.labels).map((l) => l.id).get();
    expect(ids, ['Label_12']);
  });

  test('v4 stores the Account color as its place in the palette', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute('PRAGMA user_version = 3');
    // sky, olive, and a color no version ever assigned (falls back to the position).
    for (final (id, argb, position) in [('a1', 0xFF00779E, 0), ('a2', 0xFF6B6F00, 1), ('a3', 0xFF123456, 10)]) {
      raw.execute("INSERT INTO accounts VALUES ('$id', '$id@example.com', 'gmail', $argb, $position, 'attivo')");
    }
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final colors = {for (final a in await db.select(db.accounts).get()) a.id: a.color};
    expect(colors, {'a1': 0, 'a2': 5, 'a3': 2});
  });

  test('v5 says which stored bodies are HTML and adds the offline queue', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute('PRAGMA user_version = 4');
    for (final (id, body) in [
      ('h', '<div dir="ltr">Ciao<br>Ada</div>'),
      ('p', '<p>Ciao</p>'),
      ('t', 'Ciao Ada,\r\nscrivi a <bruno@example.com>'),
    ]) {
      raw.execute("INSERT INTO bodies VALUES ('a1', '$id', '$body')");
    }
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final kinds = {for (final b in await db.select(db.bodies).get()) b.messageId: b.kind};
    expect(kinds, {'h': BodyKind.html, 'p': BodyKind.html, 't': BodyKind.testo});
    expect(await db.select(db.intents).get(), isEmpty);
  });

  test('v6 adds the Mittenti fidati, keeping what was there', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute('PRAGMA user_version = 5')
      ..execute("INSERT INTO accounts VALUES ('a1', 'a1@example.com', 'gmail', 0, 0, 'attivo')");
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.trustedSendersDao.add('ada@example.com');
    expect(await db.trustedSendersDao.watchAll().first, {'ada@example.com'});
    expect(await db.select(db.accounts).get(), hasLength(1));
  });

  test('v7 splits the stored sender into address and name, adds Cc, one recipient per line', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute('PRAGMA user_version = 6');
    for (final (id, sender, recipients) in [
      ('m1', 'Ada Okafor <ada@example.com>', 'me@example.com,Bruno <b@x.it>'),
      ('m2', 'news@shop.example', 'me@example.com'),
      ('m3', '=?UTF-8?Q?Nicol=C3=B2?= <n@x.it>', ''),
    ]) {
      raw.execute(
        "INSERT INTO messages VALUES ('a1', '$id', '<$id>', 't', '$sender', "
        "'$recipients', 'Oggetto', 'Anteprima', 0, 0, 0)",
      );
    }
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final rows = {
      for (final m in await db.select(db.messages).get()) m.id: (m.sender, m.senderName, m.recipients, m.cc),
    };
    expect(rows, {
      'm1': ('ada@example.com', 'Ada Okafor', 'me@example.com\nBruno <b@x.it>', ''),
      'm2': ('news@shop.example', null, 'me@example.com', ''),
      'm3': ('n@x.it', 'Nicolò', '', ''),
    });
  });

  test('v9 adds the attachments to the bodies: unknown for those stored before', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute('PRAGMA user_version = 4')
      ..execute("INSERT INTO bodies VALUES ('a1', 'm1', 'Ciao')");
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final body = await db.select(db.bodies).getSingle();
    expect(body.body, 'Ciao');
    expect(body.attachments, isNull);
  });

  test('v10 adds the Bozze and the Bcc of the messages', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute(
        "INSERT INTO messages VALUES ('a1', 'm1', '<m1>', 't', 'a@x.it', "
        "'me@example.com', 'Oggetto', 'Anteprima', 0, 0, 0)",
      )
      ..execute('PRAGMA user_version = 9');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.draftsDao.save(
      'a1',
      const OutgoingMessage(
        messageId: '<x>',
        from: 'a1@example.com',
        to: ['b@example.com'],
        subject: 's',
        body: '<p>Ciao</p>',
      ),
      updatedAt: 1,
    );
    expect(await db.select(db.drafts).get(), hasLength(1));
    expect((await db.customSelect('SELECT bcc FROM messages').get()).map((r) => r.read<String>('bcc')), ['']);
  });

  test('v10 clears the sync cursors, so the next sync brings the Bcc of the Bozze', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_syncCursors)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute("INSERT INTO sync_cursors VALUES ('a1', '123')")
      ..execute('PRAGMA user_version = 9');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    expect(await db.select(db.syncCursors).get(), isEmpty);
  });

  test('v17 adds the embeddings of the messages, keeping what was there', () async {
    final raw = sqlite3.openInMemory();
    // A current database taken back to the v16 shape: the embeddings dropped, one sync cursor in it.
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV17(raw);
    raw
      ..execute('DROP TABLE message_embeddings')
      ..execute("INSERT INTO sync_cursors (account_id, cursor) VALUES ('a1', '7')")
      ..execute('PRAGMA user_version = 16');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.messageEmbeddingsDao.save('a1', 'm1', 'model', [0.5, -1]);
    expect(await db.select(db.messageEmbeddings).get(), hasLength(1));
    expect((await db.select(db.syncCursors).getSingle()).cursor, '7');
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test('v16 keeps the Impostazioni di Postino to upload, but older than any copy elsewhere', () async {
    final raw = sqlite3.openInMemory();
    // A current database taken back to the v15 shape: the voci with only key and value.
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV17(raw);
    raw
      ..execute('DROP TABLE postino_settings')
      ..execute('CREATE TABLE postino_settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)')
      ..execute("INSERT INTO postino_settings VALUES ('auto_labels/a1', '{}')")
      ..execute('PRAGMA user_version = 15');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    expect(await db.postinoSettingsDao.read('auto_labels/a1'), '{}');
    final row = await db.select(db.postinoSettings).getSingle();
    // updatedAt 0: a second device migrating later never overwrites what another device already synced.
    expect((row.dirty, row.deleted, row.updatedAt), (true, false, 0));
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test('v15 adds the Impostazioni di Postino, keeping what was there', () async {
    final raw = sqlite3.openInMemory();
    // A current database taken back to the v14 shape: the Impostazioni di Postino dropped, one sync cursor in it.
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV17(raw);
    raw
      ..execute('DROP TABLE postino_settings')
      ..execute("INSERT INTO sync_cursors (account_id, cursor) VALUES ('a1', '7')")
      ..execute('PRAGMA user_version = 14');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.postinoSettingsDao.write('k', 'v', at: DateTime.utc(2026));
    expect(await db.postinoSettingsDao.read('k'), 'v');
    expect((await db.select(db.syncCursors).getSingle()).cursor, '7');
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test('v14 adds the Etichette queue, keeping what was there', () async {
    final raw = sqlite3.openInMemory();
    // A current database taken back to the v13 shape: the Etichette queue dropped, one sync cursor in it.
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV17(raw);
    raw
      ..execute('DROP TABLE postino_settings')
      ..execute('DROP TABLE label_intents')
      ..execute("INSERT INTO sync_cursors (account_id, cursor) VALUES ('a1', '7')")
      ..execute('PRAGMA user_version = 13');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.messagesDao.applySync('a1', SyncBatch(cursor: '', messages: [msg('m1')]), saveCursor: false);
    await db.intentsDao.queue('a1', ['m1'], const ApplyLabel('Label_12'));
    final row = (await db.intentsDao.pending('a1', now: 0)).single;
    expect((row.messageId, row.attribute, row.wanted, row.expected), ('m1', 'label:Label_12', 'true', 'false'));
    expect((await db.select(db.syncCursors).getSingle()).cursor, '7');
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test('v13 adds the outbox, keeping what was there', () async {
    final raw = sqlite3.openInMemory();
    // A current database taken back to the v12 shape: the outbox dropped, one sync cursor in it.
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV17(raw);
    raw
      ..execute('DROP TABLE postino_settings')
      ..execute('DROP TABLE label_intents')
      ..execute('DROP TABLE outbox')
      ..execute("INSERT INTO sync_cursors (account_id, cursor) VALUES ('a1', '7')")
      ..execute('PRAGMA user_version = 12');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.outboxDao.enqueue(
      OutboxCompanion.insert(
        accountId: 'a1',
        messageId: '<x>',
        version: 1,
        raw: 'Message-ID: <x>',
        recipients: 'b@example.com',
        cc: '',
        bcc: '',
        subject: 's',
        body: '<p>Ciao</p>',
        conversationId: const Value('t'),
        sendAfter: 1,
      ),
    );
    final row = (await db.outboxDao.due('a1', 1)).single;
    expect((row.failed, row.claimedUntil, row.conversationId), (false, null, 't'));
    expect((await db.select(db.syncCursors).getSingle()).cursor, '7');
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test(
    'v12 adds Reply-To and References to the messages and the reply headers to the Bozze, keeping what was there',
    () async {
      final raw = sqlite3.openInMemory()
        ..execute(_v3Accounts)
        ..execute(_syncCursors)
        ..execute(_v4Bodies)
        ..execute(_v4Messages)
        ..execute(
          "INSERT INTO messages VALUES ('a1', 'm1', '<m1>', 't', 'a@x.it', "
          "'me@example.com', 'Oggetto', 'Anteprima', 0, 0, 0)",
        )
        // The v4 messages schema is the v6 one: from here v7, v10, v12 and v13 all run.
        ..execute('PRAGMA user_version = 6');
      final db = PostinoDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final m = await db.select(db.messages).getSingle();
      expect((m.id, m.replyTo, m.references), ('m1', null, null));
      await db.draftsDao.save(
        'a1',
        const OutgoingMessage(
          messageId: '<x>',
          from: 'a1@example.com',
          to: ['b@example.com'],
          subject: 's',
          body: '<p>Ciao</p>',
          inReplyTo: '<m1>',
          references: ['<m1>'],
          conversationId: 't',
        ),
        updatedAt: 1,
      );
      final d = await db.select(db.drafts).getSingle();
      expect((d.inReplyTo, d.references, d.conversationId), ('<m1>', '<m1>', 't'));
      expect(raw.select('PRAGMA user_version').first.values.first, 19);
    },
  );

  test('v12 keeps a populated v10 Bozza, the reply headers and attachments empty', () async {
    final raw = sqlite3.openInMemory();
    // A current database taken back to the v10 shape: the columns of #37 dropped, one Bozza in it.
    final first = PostinoDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await first.customSelect('SELECT 1').get();
    await first.close();
    _backToV17(raw);
    for (final c in ['in_reply_to', '"references"', 'conversation_id', 'attachments']) {
      raw.execute('ALTER TABLE drafts DROP COLUMN $c');
    }
    raw
      ..execute('DROP TABLE postino_settings')
      ..execute('DROP TABLE label_intents')
      ..execute('DROP TABLE outbox')
      ..execute('ALTER TABLE messages DROP COLUMN reply_to')
      ..execute('ALTER TABLE messages DROP COLUMN "references"')
      ..execute("INSERT INTO drafts VALUES ('a1', '<x>', 'b@example.com', '', '', 's', '<p>Ciao</p>', 7, 1, 0, 0)")
      ..execute('PRAGMA user_version = 10');
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final d = await db.select(db.drafts).getSingle();
    expect((d.messageId, d.body, d.updatedAt, d.pending), ('<x>', '<p>Ciao</p>', 7, true));
    expect((d.inReplyTo, d.references, d.conversationId, d.attachments), (null, null, null, null));
    expect(raw.select('PRAGMA user_version').first.values.first, 19);
  });

  test('a new database keeps the cursors it saves', () async {
    final db = PostinoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(accountId: 'a1', cursor: '1'));
    expect(await db.select(db.syncCursors).get(), hasLength(1));
  });
}
