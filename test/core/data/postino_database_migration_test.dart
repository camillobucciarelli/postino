import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/message.dart';
import 'package:sqlite3/sqlite3.dart';

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

void main() {
  test('v3 drops the Gmail system labels cached as Etichette, keeping user ones', () async {
    final raw = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE labels (account_id TEXT NOT NULL, id TEXT NOT NULL, '
        'name TEXT NOT NULL, kind TEXT NOT NULL, PRIMARY KEY (account_id, id))',
      )
      ..execute(_v3Accounts)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
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
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
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

  test(
    'v5 says which stored bodies are HTML and adds the offline queue',
    () async {
      final raw = sqlite3.openInMemory()
        ..execute(_v3Accounts)
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

      final kinds = {
        for (final b in await db.select(db.bodies).get()) b.messageId: b.kind,
      };
      expect(kinds, {
        'h': BodyKind.html,
        'p': BodyKind.html,
        't': BodyKind.testo,
      });
      expect(await db.select(db.intents).get(), isEmpty);
    },
  );

  test('v6 adds the Mittenti fidati, keeping what was there', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
      ..execute(_v4Bodies)
      ..execute(_v4Messages)
      ..execute('PRAGMA user_version = 5');
    raw.execute(
      "INSERT INTO accounts VALUES ('a1', 'a1@example.com', 'gmail', 0, 0, 'attivo')",
    );
    final db = PostinoDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.trustedSendersDao.add('ada@example.com');
    expect(await db.trustedSendersDao.watchAll().first, {'ada@example.com'});
    expect(await db.select(db.accounts).get(), hasLength(1));
  });

  test('v7 splits the stored sender into address and name, adds Cc, one recipient per line', () async {
    final raw = sqlite3.openInMemory()
      ..execute(_v3Accounts)
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
      for (final m in await db.select(db.messages).get())
        m.id: (m.sender, m.senderName, m.recipients, m.cc),
    };
    expect(rows, {
      'm1': (
        'ada@example.com',
        'Ada Okafor',
        'me@example.com\nBruno <b@x.it>',
        '',
      ),
      'm2': ('news@shop.example', null, 'me@example.com', ''),
      'm3': ('n@x.it', 'Nicolò', '', ''),
    });
  });

  test(
    'v9 adds the attachments to the bodies: unknown for those stored before',
    () async {
      final raw = sqlite3.openInMemory()
        ..execute(_v3Accounts)
        ..execute(_v4Bodies)
        ..execute(_v4Messages)
        ..execute('PRAGMA user_version = 4');
      raw.execute("INSERT INTO bodies VALUES ('a1', 'm1', 'Ciao')");
      final db = PostinoDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final body = await db.select(db.bodies).getSingle();
      expect(body.body, 'Ciao');
      expect(body.attachments, isNull);
    },
  );
}
