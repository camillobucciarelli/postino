import 'package:drift/drift.dart' show Variable;

import '../domain/message.dart';
import 'postino_database.dart';
import 'search_index.dart';

/// Present while the bodies stored before the search index wait for their text (#221): `last` is the rowid of the last
/// body done. Not a drift table, as the index.
const _backlog = 'search_index_backlog';

/// Writes the text of a body only if the body read (row ?4, content ?5, kind ?6) is still the one stored: a body
/// replaced meanwhile was indexed by the sync, even when its new row took the old rowid (no AUTOINCREMENT).
const _backlogBodySql =
    '$indexBodySql AND EXISTS (SELECT 1 FROM bodies WHERE rowid = ?4 AND account_id = ?1 AND message_id = ?2 '
    'AND body = ?5 AND kind = ?6)';

/// Puts the bodies already stored in the backlog, if any (the migration that builds the index, ADR 0018).
Future<void> queueSearchBacklog(PostinoDatabase db) async {
  await db.customStatement('DROP TABLE IF EXISTS $_backlog');
  if ((await db.customSelect('SELECT 1 FROM bodies LIMIT 1').get()).isEmpty) return;
  await db.customStatement('CREATE TABLE $_backlog (last INTEGER NOT NULL)');
  await db.customStatement('INSERT INTO $_backlog VALUES (0)');
}

/// Indexes the bodies of the backlog, if any, [batch] at a time: their text made by [searchableTexts], each batch
/// written in one transaction with the progress, so a start killed meanwhile goes on from there. Between two batches
/// the UI isolate draws its frames. A message removed meanwhile (its Account too) has no row in the index: nothing
/// changes. Run by the app's isolate once the database is open.
Future<void> indexSearchBacklog(PostinoDatabase db, {int batch = 50}) async {
  const exists = "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = '$_backlog'";
  if ((await db.customSelect(exists).get()).isEmpty) return;
  while (true) {
    final rows = await db
        .customSelect(
          'SELECT rowid, account_id, message_id, kind, body FROM bodies '
          'WHERE rowid > (SELECT last FROM $_backlog) ORDER BY rowid LIMIT ?1',
          variables: [Variable(batch)],
        )
        .get();
    if (rows.isEmpty) return db.customStatement('DROP TABLE $_backlog');
    final texts = await searchableTexts([
      for (final r in rows) MessageBody(r.read<String>('body'), BodyKind.values.byName(r.read<String>('kind'))),
    ]);
    await db.transaction(() async {
      for (final (i, r) in rows.indexed) {
        await db.customStatement(_backlogBodySql, [
          r.read<String>('account_id'),
          r.read<String>('message_id'),
          texts[i],
          r.read<int>('rowid'),
          r.read<String>('body'),
          r.read<String>('kind'),
        ]);
      }
      await db.customStatement('UPDATE $_backlog SET last = ?1', [rows.last.read<int>('rowid')]);
    });
    // The search streams watch the bodies: an open search finds what the batch indexed.
    db.markTablesUpdated([db.bodies]);
    // A turn of the event loop: the frames due meanwhile are drawn before the next batch.
    await Future<void>.delayed(Duration.zero);
  }
}
