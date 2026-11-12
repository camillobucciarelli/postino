// The local search together with what the Provider found (#207): its Conversazioni are results even when the
// index does not match them (a word only in a body never downloaded).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/search_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/search_query.dart';

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
    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: 'c',
        messages: [
          msg('m1', subject: 'Fattura di ottobre', date: DateTime.utc(2026, 10, 3)),
          msg('m2', subject: 'Contratto', date: DateTime.utc(2026, 10, 2)),
          msg('m3', subject: 'Preventivo', date: DateTime.utc(2026, 10, 1, 1)),
          msg('s1', subject: 'Offerta', labelIds: const [spamLabelId]),
        ],
      ),
    );
    await db.messagesDao.applySync(
      'a2',
      SyncBatch(
        cursor: 'c',
        messages: [msg('n1', subject: 'Contratto')],
      ),
    );
  });

  test('the Conversazioni found on the Provider join the matches, follow each new page, never Spam', () async {
    final found = StreamController<Map<String, Set<String>>>();
    addTearDown(found.close);
    String? last;
    final sub = search
        .watchLocal(const SearchQuery(terms: ['fattura']), found: found.stream)
        .listen((entries) => last = [for (final e in entries) e.message.id].join(','));
    addTearDown(sub.cancel);
    Future<String?> after(Map<String, Set<String>> f) async {
      found.add(f);
      await pumpEventQueue();
      return last;
    }

    expect(await after(const {}), 'm1');
    expect(
      await after({
        'a1': {'t-m2', 't-s1'},
      }),
      'm1,m2',
    );
    expect(
      await after({
        'a1': {'t-m2', 't-m3'},
        'a2': {'t-n1'},
      }),
      'm1,m2,m3,n1',
    );
  });

  test('only in the Accounts searched', () async {
    final rows = search.watchLocal(
      const SearchQuery(terms: ['fattura'], accountIds: {'a1'}),
      found: Stream.value({
        'a2': {'t-n1'},
      }),
    );
    expect([for (final e in await rows.first) e.message.id], ['m1']);
  });
}
