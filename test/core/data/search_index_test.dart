// The bodies' text for the search index, made off the UI isolate (#221): the backlog of a migration, the texts of a sync.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/search_index.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/html_text.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  late PostinoDatabase db;

  setUp(() async {
    db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    for (final (i, id) in ['a1', 'a2'].indexed) {
      await MailStore(
        db,
      ).addAccount(Account(id: id, address: '$id@example.test', provider: ProviderKind.gmail, color: 0, position: i));
    }
  });

  /// The indexed body of each message, by `account/id`.
  Future<Map<String, String>> indexed() async => {
    for (final r
        in await db
            .customSelect(
              'SELECT m.account_id, m.id, s.body FROM search_index s JOIN messages m ON m.rowid = s.rowid ORDER BY m.rowid',
            )
            .get())
      '${r.read<String>('account_id')}/${r.read<String>('id')}': r.read<String>('body'),
  };

  Future<bool> backlog() async =>
      (await db.customSelect("SELECT 1 FROM sqlite_master WHERE name = 'search_index_backlog'").get()).isNotEmpty;

  /// Stores the messages and their bodies as a database before the index (v21) held them, then builds the index.
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
  }

  test('the texts are those of searchableText, in order, also when made in another isolate', () async {
    final big = '<style>.x{}</style>${'<p>parola</p>' * 2000}';
    expect(big.length, greaterThan(offIsolateHtml));
    final bodies = [
      MessageBody(big, BodyKind.html),
      const MessageBody('<b>testo</b>', BodyKind.testo),
      const MessageBody('<p>Il <b>preventivo</b></p>', BodyKind.html),
    ];
    expect(await searchableTexts(bodies), [htmlText(big), '<b>testo</b>', htmlText('<p>Il <b>preventivo</b></p>')]);
    expect(await searchableTexts(bodies.sublist(1)), [for (final b in bodies.sublist(1)) searchableText(b)]);
  });

  test('a sync page and a body opened later with much HTML are indexed', () async {
    final store = MailStore(db);
    final filler = '<p>riempitivo</p>' * 2000;
    await store.applyPage('a1', [msg('m1')], {'m1': MessageBody('<p>preventivo</p>$filler', BodyKind.html)});
    await store.saveBody('a1', 'm1', MessageBody('<p>contratto</p>$filler', BodyKind.html));
    await store.applySync(
      'a1',
      SyncBatch(
        cursor: 'c',
        messages: [msg('m2')],
        bodies: {'m2': MessageBody('<p>fattura</p>$filler', BodyKind.html)},
      ),
    );
    final texts = await indexed();
    expect(texts['a1/m1'], allOf(contains('contratto'), isNot(contains('preventivo')), isNot(contains('<p>'))));
    expect(texts['a1/m2'], contains('fattura'));
  });

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

    expect((await indexed()).map((k, v) => MapEntry(k, v.trim())), {'a1/m1': 'uno', 'a1/m2': 'due', 'a1/m3': 'tre'});
    expect(await backlog(), isFalse);
  });

  test('a start killed meanwhile goes on from the last batch done', () async {
    await beforeTheIndex({'m1': '<p>uno</p>', 'm2': '<p>due</p>'});
    final first = await db.customSelect("SELECT rowid FROM bodies WHERE message_id = 'm1'").getSingle();
    await db.customStatement('UPDATE search_index_backlog SET last = ?1', [first.read<int>('rowid')]);

    await indexSearchBacklog(db);

    expect((await indexed()).map((k, v) => MapEntry(k, v.trim())), {'a1/m1': '', 'a1/m2': 'due'});
  });

  test('a text the sync wrote meanwhile is not overwritten with the old body', () async {
    await beforeTheIndex({'m1': '<p>vecchio</p>'});
    await db.customStatement(indexBodySql, ['a1', 'm1', 'nuovo']);

    await indexSearchBacklog(db);

    expect(await indexed(), {'a1/m1': 'nuovo'});
  });

  test('an Account removed meanwhile leaves nothing in the index, and the backlog ends', () async {
    await beforeTheIndex({'m1': '<p>uno</p>'}, account: 'a2');
    await beforeTheIndex({'m2': '<p>due</p>'});
    await MailStore(db).deleteAccountRows('a2');

    await indexSearchBacklog(db);

    expect((await indexed()).map((k, v) => MapEntry(k, v.trim())), {'a1/m2': 'due'});
    expect(await backlog(), isFalse);
  });
}
