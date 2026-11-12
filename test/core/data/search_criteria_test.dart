// The criteria of the local search (#206): unread, Stella, attachments, Account and days, alone and with text.
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
    for (final (i, address) in ['anna@example.test', 'bruno@example.test'].indexed) {
      await MailStore(db)
          .addAccount(Account(id: 'a$i', address: address, provider: ProviderKind.gmail, color: 0, position: i));
    }
  });

  Future<void> sync(String account, List<Message> messages) =>
      db.messagesDao.applySync(account, SyncBatch(cursor: 'c', messages: messages));

  Future<List<String>> find(String input, {Set<String> accounts = const {}}) async => [
    for (final e in await search.watchLocal(parseSearchQuery(input).inAccounts(accounts)).first)
      '${e.account.id}/${e.message.id}',
  ];

  test('unread: a Conversazione counts when one of its messages is unread, as in the lists', () async {
    await sync('a0', [
      msg('m1', conversationId: 'c1', isRead: true),
      msg('m2', conversationId: 'c1', date: DateTime.utc(2026, 1, 2)),
      msg('m3', conversationId: 'c2', isRead: true),
    ]);
    expect(await find('è:nonletto'), ['a0/m2']);
    expect(await find('is:unread'), ['a0/m2']);
  });

  test('starred: a Conversazione counts when one of its messages has the Stella', () async {
    await sync('a0', [
      msg('m1', conversationId: 'c1', isStarred: true),
      msg('m2', conversationId: 'c1', date: DateTime.utc(2026, 1, 2)),
      msg('m3', conversationId: 'c2'),
    ]);
    expect(await find('è:stella'), ['a0/m2']);
  });

  test('attachments: only the messages known to have some', () async {
    await sync('a0', [msg('yes', hasAttachments: true), msg('no', hasAttachments: false), msg('unknown')]);
    expect(await find('ha:allegato'), ['a0/yes']);
    expect(await find('has:attachment'), ['a0/yes']);
  });

  test('a body downloaded later corrects the guess of the sync, and an unknown sync does not undo it', () async {
    await sync('a0', [msg('m1', hasAttachments: true), msg('m2'), msg('m3', hasAttachments: false)]);
    await db.bodiesDao.saveBody('a0', 'm1', const MessageBody('niente', BodyKind.testo));
    await db.bodiesDao.saveBody(
      'a0',
      'm2',
      const MessageBody(
        'c è un file',
        BodyKind.testo,
        attachments: [Attachment(id: '2', name: 'a.pdf', size: 3)],
      ),
    );
    await db.bodiesDao.saveBody('a0', 'm3', const MessageBody('ignoto', BodyKind.testo, attachments: null));
    expect(await find('ha:allegato'), ['a0/m2'], reason: 'm1 corrected to none, m2 to some, m3 kept its own');

    await sync('a0', [msg('m2', isRead: true)]);
    expect(await find('ha:allegato'), ['a0/m2'], reason: 'a sync that does not know does not erase it');

    await sync('a0', [msg('m1', hasAttachments: true), msg('m2', hasAttachments: false)]);
    expect(await find('ha:allegato'), ['a0/m2'], reason: 'a header guess does not undo what the stored body said');
  });

  test('days are the local ones, both ends included', () async {
    await sync('a0', [
      msg('before', date: DateTime(2026, 3, 4, 23, 59, 59)),
      msg('first', date: DateTime(2026, 3, 5)),
      msg('last', date: DateTime(2026, 3, 6, 23, 59, 59)),
      msg('after', date: DateTime(2026, 3, 7)),
    ]);
    expect(await find('dopo:2026-03-05 prima:2026-03-06'), unorderedEquals(['a0/first', 'a0/last']));
    expect(await find('dopo:2026-03-07'), ['a0/after']);
    expect(await find('prima:2026-03-04'), ['a0/before']);
    expect(await find('after:2026-03-05 before:2026-03-05'), ['a0/first']);
  });

  test('account: by part of the address; more names are alternatives; the scope still applies', () async {
    await sync('a0', [msg('m1')]);
    await sync('a1', [msg('m2')]);
    expect(await find('account:anna'), ['a0/m1']);
    expect(await find('ACCOUNT:Bruno'), ['a1/m2']);
    expect(await find('account:anna account:bruno'), unorderedEquals(['a0/m1', 'a1/m2']));
    expect(await find('account:anna', accounts: {'a1'}), isEmpty);
    expect(await find('account:nessuno'), isEmpty);
    expect(await find('account:a_na'), isEmpty, reason: '_ is not a wildcard');
    expect(await find('account:%'), isEmpty, reason: '% is not a wildcard');
  });

  test('criteria combine in AND with the text, and alone are a valid search', () async {
    await sync('a0', [
      msg('m1', subject: 'Fattura', hasAttachments: true),
      msg('m2', subject: 'Fattura', isRead: true, hasAttachments: true),
      msg('m3', subject: 'Altro', hasAttachments: true),
      msg('m4', subject: 'Fattura', hasAttachments: false),
    ]);
    expect(await find('fattura è:nonletto ha:allegato'), ['a0/m1']);
    expect(await find('è:nonletto ha:allegato'), unorderedEquals(['a0/m1', 'a0/m3']));
    expect(await find('fattura'), hasLength(3));
  });

  test('text and criteria are each looked up in the Conversazione, not all in one message', () async {
    await sync('a0', [
      msg('m1', conversationId: 'c1', subject: 'Preventivo', isRead: true),
      msg('m2', conversationId: 'c1', subject: 'Re: ok', date: DateTime.utc(2026, 1, 2)),
    ]);
    expect(await find('preventivo è:nonletto'), ['a0/m2']);
  });

  test('Spam counts for no criterion', () async {
    await sync('a0', [
      msg('m1', conversationId: 'c1', isRead: true),
      msg('m2', conversationId: 'c1', labelIds: [spamLabelId]),
      msg('m3', conversationId: 'c2', labelIds: [spamLabelId]),
    ]);
    expect(await find('è:nonletto'), isEmpty);
  });

  test('a text that is no word narrows nothing: no results, even with a criterion', () async {
    await sync('a0', [msg('m1')]);
    expect(await find('è:nonletto ***'), isEmpty);
  });

  test('the results follow the writes', () async {
    final results = <List<String>>[];
    final sub = search
        .watchLocal(parseSearchQuery('è:nonletto'))
        .listen((r) => results.add([for (final e in r) e.message.id]));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await sync('a0', [msg('m1')]);
    await pumpEventQueue();
    expect(results.last, ['m1']);
    await sync('a0', [msg('m1', isRead: true)]);
    await pumpEventQueue();
    expect(results.last, isEmpty);
  });

  test('special characters in the operator values never reach the index as syntax', () async {
    await sync('a0', [msg('m1', subject: 'orario NEAR uno', from: 'ada@example.test')]);
    for (final input in [
      'da:"*" a:(OR) oggetto:NEAR(',
      'da:a:b è:"x" dopo:"2026-01-01',
      'oggetto:"" da:-ada',
      'da:ada* OR a:"x" "NEAR/2" -foo',
      'account:"\' OR 1=1 --"',
    ]) {
      await find(input); // it must not throw an SQL or FTS5 syntax error
    }
    expect(await find('da:"ada" oggetto:near'), ['a0/m1']);
    expect(await db.select(db.messages).get(), hasLength(1));
  });
}
