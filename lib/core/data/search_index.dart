import 'dart:isolate';

import '../domain/html_text.dart';
import '../domain/message.dart';
import 'postino_database.dart';

/// The columns of the index, in the order the SQL below fills them.
const _columns = 'subject, sender, recipients, snippet, body';

const _senderOf = "new.sender || ' ' || coalesce(new.sender_name, '')";
const _recipientsOf = "new.recipients || ' ' || new.cc";

/// The full-text index of the messages (#205): an FTS5 table whose rowid is the rowid of the message it indexes.
/// `unicode61` ignores case and accents; the `prefix` indexes make the first letters typed fast, from one.
/// The triggers keep the columns of `messages` in step with every write, whoever makes it; the body is plain text
/// only Dart can make from the HTML, so `indexBodySql` keeps that column.
const searchIndexStatements = [
  'CREATE VIRTUAL TABLE search_index USING fts5($_columns, '
      "tokenize = 'unicode61 remove_diacritics 2', prefix = '1 2 3')",
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

/// Past this much HTML the texts are made in another isolate: parsing it on the UI one drops frames (#221).
// ponytail: below it (a few ms of parsing) an isolate costs more than it saves.
const offIsolateHtml = 16 * 1024;

/// The [searchableText] of each body, in order; in another isolate when they hold more than [offIsolateHtml] of HTML.
/// HTML the parser cannot read (nested past its stack) has no text: it is not searched, the others are.
Future<List<String>> searchableTexts(List<MessageBody> bodies) async {
  final html = bodies.fold(0, (n, b) => b.kind == BodyKind.html ? n + b.content.length : n);
  final sent = [for (final b in bodies) (b.content, b.kind == BodyKind.html)];
  return html <= offIsolateHtml ? _texts(sent) : Isolate.run(() => _texts(sent));
}

List<String> _texts(List<(String, bool)> bodies) => [
  for (final (content, isHtml) in bodies)
    if (!isHtml) content else _htmlTextOrNothing(content),
];

String _htmlTextOrNothing(String html) {
  try {
    return htmlText(html);
  } on Error {
    // ponytail: StackOverflowError on very deep nesting; an iterative walk in htmlText if such mail must be found.
    return '';
  }
}

/// The [searchableTexts] of bodies keyed by message id.
Future<Map<String, String>> searchableTextsOf(Map<String, MessageBody> bodies) async =>
    Map.fromIterables(bodies.keys, await searchableTexts([...bodies.values]));

/// Creates the index and fills it with the messages already stored (v22, or a new database). The bodies already
/// stored are not: their text is made out of the migration, by the backlog (`search_index_backlog.dart`, #221).
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
}
