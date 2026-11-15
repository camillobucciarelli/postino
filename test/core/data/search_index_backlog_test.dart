// The bodies stored before the search index get their text out of the migration, a batch at a time (#221, ADR 0018).
import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/search_index.dart';
import 'package:postino/core/data/search_index_backlog.dart';
import 'package:postino/core/data/search_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/search_query_parser.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  late PostinoDatabase db;
  late _AfterRead afterRead;

  setUp(() async {
    afterRead = _AfterRead();
    db = PostinoDatabase(NativeDatabase.memory().interceptWith(afterRead));
    addTearDown(db.close);
    for (final (i, id) in ['a1', 'a2'].indexed) {
      await MailStore(
        db,
      ).addAccount(Account(id: id, address: '$id@example.test', provider: ProviderKind.gmail, color: 0, position: i));
    }
  });

  /// The indexed body of each message, by `account/id`, trimmed.
  Future<Map<String, String>> indexed() async => {
    for (final r
        in await db
            .customSelect(
              'SELECT m.account_id, m.id, s.body FROM search_index s JOIN messages m ON m.rowid = s.rowid ORDER BY m.rowid',
            )
            .get())
      '${r.read<String>('account_id')}/${r.read<String>('id')}': r.read<String>('body').trim(),
  };

  Future<bool> backlog() async =>
      (await db.customSelect("SELECT 1 FROM sqlite_master WHERE name = 'search_index_backlog'").get()).isNotEmpty;

  /// Stores the messages and their bodies as a database before the index (v21) held them, then builds the index and
  /// its backlog as the migration does.
  Future<void> beforeTheIndex(Map<String, String> htmlById, {String account = 'a1'}) async {
    await db.messagesDao.applySync(
      account,
      SyncBatch(cursor: 'c', messages: [for (final id in htmlById.keys) msg(id)]),
    );
    for (final MapEntry(key: id, value: html) in htmlById.entries) {
      await db.customStatement("INSERT INTO bodies (account_id, message_id, body, kind) VALUES (?1, ?2, ?3, 'html')", [
        account,
        id,
        html,
      ]);
    }
    await createSearchIndex(db);
    await queueSearchBacklog(db);
  }

  test('a new database has no backlog', () async {
    expect(await backlog(), isFalse);
    await indexSearchBacklog(db);
    expect(await backlog(), isFalse);
  });

  test('the bodies already stored are indexed by the backlog, a batch at a time, then the backlog goes', () async {
    await beforeTheIndex({'m1': '<p>uno</p>', 'm2': '<p>due</p>', 'm3': '<p>tre</p>'});
    expect((await indexed()).values, everyElement(isEmpty), reason: 'not in the migration');
    expect(await backlog(), isTrue);

    await indexSearchBacklog(db, batch: 2);

    expect(await indexed(), {'a1/m1': 'uno', 'a1/m2': 'due', 'a1/m3': 'tre'});
    expect(await backlog(), isFalse);
  });

  test('a start killed meanwhile goes on from the last batch done', () async {
    await beforeTheIndex({'m1': '<p>uno</p>', 'm2': '<p>due</p>'});
    final first = await db.customSelect("SELECT rowid FROM bodies WHERE message_id = 'm1'").getSingle();
    await db.customStatement('UPDATE search_index_backlog SET last = ?1', [first.read<int>('rowid')]);

    await indexSearchBacklog(db);

    expect(await indexed(), {'a1/m1': '', 'a1/m2': 'due'});
  });

  for (final (how, replace) in [
    (
      'in a new row',
      "INSERT OR REPLACE INTO bodies (account_id, message_id, body, kind) VALUES ('a1', 'm1', '<img>', 'html')",
    ),
    // Removed and inserted again: without AUTOINCREMENT the last rowid comes back.
    ('in a row with the same rowid', "UPDATE bodies SET body = '<img>' WHERE account_id = 'a1' AND message_id = 'm1'"),
  ]) {
    test('a body replaced $how while its batch is parsed keeps the new text, even an empty one', () async {
      await beforeTheIndex({'m1': '<p>vecchio</p>'});
      // Between the read of the batch and its write: a Bozza saved again, with only an image.
      afterRead.run = (e) async {
        await e.runCustom(replace);
        await e.runCustom(indexBodySql, ['a1', 'm1', '']);
      };

      await indexSearchBacklog(db);

      expect(await indexed(), {'a1/m1': ''});
      expect(await backlog(), isFalse);
    });
  }

  test('an open search finds what the backlog indexed', () async {
    await beforeTheIndex({'m1': '<p>preventivo</p>'});
    final results = <int>[];
    final sub = SearchStore(db).watchLocal(parseSearchQuery('preventivo')).listen((r) => results.add(r.length));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(results.last, 0);

    await indexSearchBacklog(db);
    await pumpEventQueue();

    expect(results.last, 1);
  });

  test('an Account removed meanwhile leaves nothing in the index, and the backlog ends', () async {
    await beforeTheIndex({'m1': '<p>uno</p>'}, account: 'a2');
    await beforeTheIndex({'m2': '<p>due</p>'});
    await MailStore(db).deleteAccountRows('a2');

    await indexSearchBacklog(db);

    expect(await indexed(), {'a1/m2': 'due'});
    expect(await backlog(), isFalse);
  });
}

/// Runs [run], once, right after the backlog reads a batch of bodies.
class _AfterRead() extends QueryInterceptor {
  Future<void> Function(QueryExecutor)? run;

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) async {
    final rows = await super.runSelect(executor, statement, args);
    if (statement.contains('FROM bodies WHERE rowid >') && run != null) {
      final r = run!;
      run = null;
      await r(executor);
    }
    return rows;
  }
}
