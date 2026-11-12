import 'package:drift/drift.dart' show Variable;

import '../domain/html_text.dart';
import '../domain/message.dart';
import 'postino_database.dart';

/// The columns of the index, in the order the SQL below fills them.
const _columns = 'subject, sender, recipients, snippet, body';

const _senderOf = "new.sender || ' ' || coalesce(new.sender_name, '')";
const _recipientsOf = "new.recipients || ' ' || new.cc";

/// The full-text index of the messages (#205): an FTS5 table whose rowid is the rowid of the message it indexes.
/// `unicode61` ignores case and accents; the `prefix` indexes make the first letters typed fast.
/// The triggers keep the columns of `messages` in step with every write, whoever makes it; the body is plain text
/// only Dart can make from the HTML, so `indexBodySql` keeps that column.
const searchIndexStatements = [
  'CREATE VIRTUAL TABLE search_index USING fts5($_columns, '
      "tokenize = 'unicode61 remove_diacritics 2', prefix = '2 3')",
  'CREATE TRIGGER search_index_insert AFTER INSERT ON messages BEGIN '
      'INSERT OR REPLACE INTO search_index (rowid, $_columns) '
      "VALUES (new.rowid, new.subject, $_senderOf, $_recipientsOf, new.snippet, ''); END",
  'CREATE TRIGGER search_index_update AFTER UPDATE ON messages '
      'WHEN old.subject IS NOT new.subject OR old.sender IS NOT new.sender OR old.sender_name IS NOT new.sender_name '
      'OR old.recipients IS NOT new.recipients OR old.cc IS NOT new.cc OR old.snippet IS NOT new.snippet BEGIN '
      'UPDATE search_index SET subject = new.subject, sender = $_senderOf, recipients = $_recipientsOf, '
      'snippet = new.snippet WHERE rowid = new.rowid; END',
  'CREATE TRIGGER search_index_delete AFTER DELETE ON messages BEGIN '
      'DELETE FROM search_index WHERE rowid = old.rowid; END',
];

/// Sets the indexed body of a message; a message not stored (yet) has no row, so nothing changes.
const indexBodySql =
    'UPDATE search_index SET body = ?3 WHERE rowid = (SELECT rowid FROM messages WHERE account_id = ?1 AND id = ?2)';

/// What of a body is searched: the text a reader sees.
String searchableText(MessageBody body) => body.kind == BodyKind.html ? htmlText(body.content) : body.content;

/// Creates the index and fills it with the messages and bodies already stored (v22, or a new database).
/// Starts from nothing: a database taken back to an older version may hold a half of it.
Future<void> createSearchIndex(PostinoDatabase db) async {
  for (final s in [
    'DROP TRIGGER IF EXISTS search_index_insert',
    'DROP TRIGGER IF EXISTS search_index_update',
    'DROP TRIGGER IF EXISTS search_index_delete',
    'DROP TABLE IF EXISTS search_index',
    ...searchIndexStatements,
  ]) {
    await db.customStatement(s);
  }
  await db.customStatement(
    'INSERT INTO search_index (rowid, $_columns) '
    "SELECT rowid, subject, sender || ' ' || coalesce(sender_name, ''), recipients || ' ' || cc, snippet, '' "
    'FROM messages',
  );
  // By pages: the bodies of a mailbox do not fit in memory at once.
  var last = 0;
  while (true) {
    final rows = await db
        .customSelect(
          'SELECT rowid, account_id, message_id, kind, body FROM bodies WHERE rowid > ?1 ORDER BY rowid LIMIT 200',
          variables: [Variable(last)],
        )
        .get();
    if (rows.isEmpty) return;
    for (final r in rows) {
      final body = MessageBody(r.read<String>('body'), BodyKind.values.byName(r.read<String>('kind')));
      await db.customStatement(indexBodySql, [
        r.read<String>('account_id'),
        r.read<String>('message_id'),
        searchableText(body),
      ]);
    }
    last = rows.last.read<int>('rowid');
  }
}
