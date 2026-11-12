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
    // Every prefix, a single letter matching all 20.000 too: the threshold of #216.
    expect(times.reduce((a, b) => a > b ? a : b), lessThan(50));
  });
}
