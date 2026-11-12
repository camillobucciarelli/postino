// Contatti (#216) from the messages in the database: every Account, the Inviati weigh more, the Accounts'
// own addresses left out, nothing left by a removed Account; the query under 50 ms on 20.000 messages.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/contacts_store.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_platform.dart';

final _now = DateTime.utc(2026, 11, 12, 12);

void main() {
  late PostinoDatabase db;
  late ContactsStore store;
  setUp(() async {
    db = PostinoDatabase.inMemory();
    store = ContactsStore(db, FakeClock(_now));
    for (final (i, id) in ['a1', 'a2'].indexed) {
      await db.accountsDao.upsert(
        Account(
          id: id,
          address: '${id.toUpperCase()}@example.com',
          provider: ProviderKind.gmail,
          color: 0,
          position: i,
        ),
      );
    }
  });
  tearDown(() => db.close());

  DateTime ago(int days) => _now.subtract(Duration(days: days));

  Future<List<String>> suggest(String prefix) async => [
    for (final c in await store.suggest(prefix)) c.name == null ? c.address : '${c.name} <${c.address}>',
  ];

  test('from every Account; the Inviati weigh more; the Accounts\' addresses are never suggested', () async {
    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: '1',
        messages: [
          for (var d = 0; d < 60; d++)
            msg('n$d', from: 'marketing@example.com', fromName: 'Market', to: ['a1@example.com'], date: ago(d)),
          msg('r1', from: 'Maria@Example.com', fromName: 'M. Rossi', to: ['a1@example.com'], date: ago(20)),
        ],
      ),
    );
    await db.messagesDao.applySync(
      'a2',
      SyncBatch(
        cursor: '1',
        messages: [
          msg(
            's1',
            from: 'a2@example.com',
            to: ['Maria Rossi <maria@example.com>'],
            cc: ['a1@example.com'],
            labelIds: const [sentLabelId],
            date: ago(1),
          ),
        ],
      ),
    );
    expect(await suggest('mar'), ['Maria Rossi <maria@example.com>', 'Market <marketing@example.com>']);
    expect(await suggest('a'), isEmpty);
    expect(await suggest('Rossi'), ['Maria Rossi <maria@example.com>']);
  });

  test('found by name, a Contatto counts the messages to its bare address and has its newest name', () async {
    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: '1',
        messages: [
          for (var d = 0; d < 30; d++)
            msg('n$d', from: 'rossini@example.com', fromName: 'Negozio Rossini', date: ago(d)),
          msg('r1', from: 'x@example.com', fromName: 'Maria Rossi', date: ago(40)),
          for (var d = 1; d < 4; d++)
            msg('s$d', from: 'a1@example.com', to: ['x@example.com'], labelIds: const [sentLabelId], date: ago(d)),
        ],
      ),
    );
    expect(await suggest('rossi'), ['Maria Rossi <x@example.com>', 'Negozio Rossini <rossini@example.com>']);

    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: '2',
        messages: [msg('r2', from: 'x@example.com', fromName: 'Maria Bianchi', date: ago(0))],
      ),
    );
    expect(await suggest('bianchi'), ['Maria Bianchi <x@example.com>']);
    // The old name no longer matches: the Contatto is called by its newest one.
    expect(await suggest('rossi'), ['Negozio Rossini <rossini@example.com>']);
  });

  test('LIKE wildcards in the prefix are literal; a non-ASCII prefix matches any case', () async {
    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: '1',
        messages: [
          msg('m1', fromName: 'Élodie Durand'),
          msg('m2', from: 'a_b@example.com'),
          msg('m3', from: 'axb@example.com'),
        ],
      ),
    );
    expect(await suggest('a_'), ['a_b@example.com']);
    expect(await suggest('a%'), isEmpty);
    expect(await suggest('él'), ['Élodie Durand <ada@example.com>']);
  });

  test('a removed Account leaves no Contatti of its own', () async {
    await db.messagesDao.applySync(
      'a2',
      SyncBatch(
        cursor: '1',
        messages: [msg('m1', from: 'bo@example.com')],
      ),
    );
    expect(await suggest('bo'), ['bo@example.com']);
    await MailStore(db).removeAccount('a2', at: _now);
    expect(await suggest('bo'), isEmpty);
  });

  test('performance: 20.000 messages answer within 50 ms', () async {
    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: '1',
        messages: [
          for (var i = 0; i < 20000; i++)
            msg(
              'm$i',
              from: 'p${i % 2000}@example.com',
              fromName: 'Persona ${i % 2000}',
              to: ['a1@example.com', 'Collega ${i % 300} <c${i % 300}@example.com>'],
              cc: ['team${i % 50}@example.com'],
              date: ago(i % 365),
            ),
        ],
      ),
    );
    await store.suggest('p1'); // warm up: the first query compiles the statement
    final times = <int>[];
    for (final prefix in ['p', 'pe', 'c1', 'team', 'persona 1']) {
      final s = Stopwatch()..start();
      final r = await store.suggest(prefix);
      times.add(s.elapsedMilliseconds);
      expect(r, isNotEmpty, reason: prefix);
    }
    // ignore: avoid_print, the measure goes in the PR.
    print('contacts suggest on 20000 messages: $times ms');
    // The median: a wall clock on a shared runner (tests run in parallel) has outliers the query does not.
    expect((times..sort())[times.length ~/ 2], lessThan(50));
  });
}
