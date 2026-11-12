// The local search (#205): the full-text index of the database, kept in step with every write.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/search_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/search_query_parser.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  late PostinoDatabase db;
  late SearchStore search;

  setUp(() async {
    db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    search = SearchStore(db);
    for (final (i, id) in ['a1', 'a2'].indexed) {
      await MailStore(
        db,
      ).addAccount(Account(id: id, address: '$id@example.test', provider: ProviderKind.gmail, color: 0, position: i));
    }
  });

  Future<void> sync(String account, List<Message> messages, {Map<String, MessageBody> bodies = const {}}) =>
      db.messagesDao.applySync(account, SyncBatch(cursor: 'c', messages: messages, bodies: bodies));

  /// The `account/message` of each row found by [input], newest first.
  Future<List<String>> find(String input, {Set<String> accounts = const {}}) async => [
    for (final e in await search.watchLocal(parseSearchQuery(input).inAccounts(accounts)).first)
      '${e.account.id}/${e.message.id}',
  ];

  test('the build used by the tests has FTS5', () async {
    expect(await db.customSelect('SELECT count(*) AS n FROM search_index').getSingle(), isNotNull);
  });

  test('finds by subject, sender address and name, recipients (A and Cc), preview', () async {
    await sync('a1', [
      msg('m1', subject: 'Fattura di ottobre', from: 'ada@example.test', fromName: 'Ada Lovelace'),
      msg(
        'm2',
        from: 'zeno@example.test',
        to: ['bruno@example.test'],
        cc: ['carla@example.test'],
        snippet: 'Ci vediamo in magazzino',
      ),
    ]);

    expect(await find('fattura'), ['a1/m1']);
    expect(await find('da:ada'), ['a1/m1']);
    expect(await find('lovelace'), ['a1/m1']);
    expect(await find('a:bruno'), ['a1/m2']);
    expect(await find('a:carla'), ['a1/m2']);
    expect(await find('magazzino'), ['a1/m2']);
    expect(await find('oggetto:ottobre'), ['a1/m1']);
  });

  test('the operators look only in their field', () async {
    await sync('a1', [
      msg('m1', subject: 'Ada', from: 'bruno@example.test'),
      msg('m2', subject: 'Altro', from: 'ada@example.test'),
    ]);
    expect(await find('da:ada'), ['a1/m2']);
    expect(await find('oggetto:ada'), ['a1/m1']);
    expect(await find('ada'), ['a1/m1', 'a1/m2'], reason: 'free text looks everywhere');
  });

  test('a word matches as a beginning, case and accents ignored', () async {
    await sync('a1', [msg('m1', subject: 'Perché la città è chiusa')]);
    expect(await find('fatt'), isEmpty);
    expect(await find('citta'), ['a1/m1']);
    expect(await find('CITT'), ['a1/m1']);
    expect(await find('perche'), ['a1/m1']);
    expect(await find('ittà'), isEmpty, reason: 'not from the middle of a word');
  });

  test('every word must match; a phrase matches whole words in order', () async {
    await sync('a1', [msg('m1', subject: 'Nota spese di ottobre'), msg('m2', subject: 'Spese e nota di ottobre')]);
    expect(await find('nota ottobre'), hasLength(2));
    expect(await find('nota ottobre rimborso'), isEmpty);
    expect(await find('"nota spese"'), ['a1/m1']);
  });

  test('finds the downloaded body, HTML as the text a reader sees', () async {
    await sync(
      'a1',
      [msg('m1'), msg('m2'), msg('m3')],
      bodies: {
        'm1': const MessageBody('<div class="x"><p>Il <b>preventivo</b> è allegato</p></div>', BodyKind.html),
        'm2': const MessageBody('Il preventivo e il contratto', BodyKind.testo),
      },
    );
    expect(await find('preventivo'), hasLength(2));
    expect(await find('contratto'), ['a1/m2']);
    expect(await find('div'), isEmpty, reason: 'tags are not text');
    expect(await find('class'), isEmpty);
    await sync(
      'a1',
      [msg('m4')],
      bodies: {'m4': const MessageBody('<style>.x { color: red }</style><p>Ciao</p>', BodyKind.html)},
    );
    expect(await find('color'), isEmpty, reason: 'CSS is not text');
    expect(await find('ciao'), ['a1/m4']);
  });

  test('a body saved later, and a message synced again, stay searchable', () async {
    await sync('a1', [msg('m1', subject: 'Prima')]);
    await db.bodiesDao.saveBody('a1', 'm1', const MessageBody('contenuto scaricato dopo', BodyKind.testo));
    expect(await find('scaricato'), ['a1/m1']);

    // The next sync brings the message again, flags changed and subject edited: the body is still there.
    await sync('a1', [msg('m1', subject: 'Seconda', isRead: true)]);
    expect(await find('scaricato'), ['a1/m1']);
    expect(await find('seconda'), ['a1/m1']);
    expect(await find('prima'), isEmpty, reason: 'the old subject is gone from the index');
  });

  test('a message removed by the sync, or absent from a full snapshot, is no longer found', () async {
    await sync('a1', [msg('m1', subject: 'uno'), msg('m2', subject: 'due'), msg('m3', subject: 'tre')]);
    await db.messagesDao.applySync('a1', const SyncBatch(cursor: 'c2', removedMessageIds: ['m1']));
    expect(await find('uno'), isEmpty);
    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: 'c3',
        messages: [msg('m3', subject: 'tre')],
      ),
      fullSnapshot: true,
    );
    expect(await find('due'), isEmpty);
    expect(await find('tre'), ['a1/m3']);
  });

  test('the Account removed leaves no trace in the results', () async {
    await sync(
      'a1',
      [msg('m1', subject: 'segreto')],
      bodies: {'m1': const MessageBody('segreto nel corpo', BodyKind.testo)},
    );
    await sync('a2', [msg('m2', subject: 'segreto')]);
    await MailStore(db).removeAccount('a1', at: DateTime.utc(2026));
    expect(await find('segreto'), ['a2/m2']);
    expect(await db.customSelect("SELECT rowid FROM search_index WHERE search_index MATCH 'corpo'").get(), isEmpty);
  });

  test('one row per Conversazione, the most recent first, with its count', () async {
    await sync('a1', [
      msg('m1', conversationId: 'c1', subject: 'Gara'),
      msg('m2', conversationId: 'c1', subject: 'Re: Gara', date: DateTime.utc(2026, 3, 5)),
      msg('m3', conversationId: 'c2', subject: 'Gara bis', date: DateTime.utc(2026, 3, 3)),
      msg('m4', conversationId: 'c3', subject: 'Altro', date: DateTime.utc(2026, 3, 9)),
    ]);
    final rows = await search.watchLocal(parseSearchQuery('gara')).first;
    expect([for (final e in rows) e.message.id], ['m2', 'm3']);
    expect([for (final e in rows) e.count], [2, 1]);
  });

  test('the Account scope narrows the search; none searches them all', () async {
    await sync('a1', [msg('m1', subject: 'orario')]);
    await sync('a2', [msg('m2', subject: 'orario')]);
    expect(await find('orario'), unorderedEquals(['a1/m1', 'a2/m2']));
    expect(await find('orario', accounts: {'a2'}), ['a2/m2']);
  });

  test('nothing to look for finds nothing; what the user types is never search syntax', () async {
    await sync('a1', [msg('m1', subject: "L'asta ** e OR \"NEAR\" - tutto")]);
    expect(await find(''), isEmpty);
    expect(await find('   '), isEmpty);
    expect(await find('!!! ???'), isEmpty);
    expect(await find("l'asta"), ['a1/m1']);
    expect(await find('** OR NEAR('), ['a1/m1']);
    expect(await find('"unclosed'), isEmpty);
    expect(await find("a'; DROP TABLE messages; --"), isEmpty);
    expect(await db.select(db.messages).get(), hasLength(1));
  });

  test('the results follow the writes', () async {
    final results = <List<String>>[];
    final sub = search
        .watchLocal(parseSearchQuery('novita'))
        .listen((r) => results.add([for (final e in r) e.message.id]));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await sync('a1', [msg('m1', subject: 'Novità')]);
    await pumpEventQueue();
    expect(results.last, ['m1']);
    await db.messagesDao.applySync('a1', const SyncBatch(cursor: 'c2', removedMessageIds: ['m1']));
    await pumpEventQueue();
    expect(results.last, isEmpty);
  });

  test('20,000 messages answer in well under a second', () async {
    final all = [
      for (var i = 0; i < 20000; i++)
        msg(
          'm$i',
          subject: 'Oggetto numero $i riunione${i % 50}',
          from: 'mittente${i % 200}@example.test',
          snippet: 'anteprima${i % 97} del messaggio $i',
          date: DateTime.utc(2026).add(Duration(minutes: i)),
        ),
    ];
    for (var start = 0; start < all.length; start += 2000) {
      await sync('a1', all.sublist(start, start + 2000));
    }
    final watch = Stopwatch()..start();
    final rows = await search.watchLocal(parseSearchQuery('riunione7 da:mittente7')).first;
    watch.stop();
    expect(rows, isNotEmpty);
    // Generous: the real figure is a few milliseconds; this only catches a scan per keystroke.
    expect(watch.elapsedMilliseconds, lessThan(100), reason: '${watch.elapsedMilliseconds} ms');
  });
}
