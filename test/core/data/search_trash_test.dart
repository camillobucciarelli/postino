// The Cestino and the local search (#236): out of every search, but the one opened from the Cestino.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/search_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/search_query.dart';
import 'package:postino/core/domain/search_query_parser.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  late PostinoDatabase db;
  late SearchStore search;

  setUp(() async {
    db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    search = SearchStore(db);
    for (final (i, id) in ['a0', 'a1'].indexed) {
      await MailStore(
        db,
      ).addAccount(Account(id: id, address: '$id@example.test', provider: ProviderKind.gmail, color: 0, position: i));
    }
  });

  Future<void> sync(String account, List<Message> messages) =>
      db.messagesDao.applySync(account, SyncBatch(cursor: 'c', messages: messages));

  Future<List<String>> find(String input, {bool trash = false, Set<String> accounts = const {}}) async => [
    for (final e
        in await search
            .watchLocal(parseSearchQuery(input).inAccounts(accounts).inLabel(trash ? trashLabelId : null))
            .first)
      '${e.account.id}/${e.message.id}',
  ];

  test('a message in the Cestino is found by no text nor criterion', () async {
    await sync('a0', [
      msg('m1', subject: 'Rarissimo', from: 'ada@example.test', labelIds: [trashLabelId]),
    ]);
    expect(await find('rarissimo'), isEmpty);
    expect(await find('da:ada'), isEmpty);
    expect(await find('oggetto:rarissimo'), isEmpty);
    expect(await find('è:nonletto'), isEmpty);
  });

  test('a Conversazione with a message in the Cestino shows the other one; one only there does not show', () async {
    await sync('a0', [
      msg('m1', conversationId: 'c1', subject: 'Rarissimo', labelIds: [trashLabelId]),
      msg('m2', conversationId: 'c1', subject: 'Rarissimo'),
      msg('m3', conversationId: 'c2', subject: 'Rarissimo', labelIds: [trashLabelId]),
    ]);
    expect(await find('rarissimo'), ['a0/m2']);
  });

  test('from the Cestino: its messages of the Account, no others', () async {
    await sync('a0', [
      msg('m1', subject: 'Rarissimo', labelIds: [trashLabelId]),
      msg('m2', subject: 'Rarissimo'),
    ]);
    await sync('a1', [
      msg('m3', subject: 'Rarissimo', labelIds: [trashLabelId]),
    ]);
    expect(await find('rarissimo', trash: true, accounts: {'a0'}), ['a0/m1']);
    expect(await find('rarissimo', trash: true), hasLength(2));
    expect(await find('è:nonletto', trash: true, accounts: {'a1'}), ['a1/m3']);
  });

  test('a message restored from the Cestino is found again', () async {
    await sync('a0', [
      msg('m1', subject: 'Rarissimo', labelIds: [trashLabelId]),
    ]);
    expect(await find('rarissimo'), isEmpty);
    await sync('a0', [msg('m1', subject: 'Rarissimo')]);
    expect(await find('rarissimo'), ['a0/m1']);
    expect(await find('rarissimo', trash: true), isEmpty);
  });

  test('the scope is not written by the user', () {
    expect(parseSearchQuery('label:TRASH in:trash cestino').labelId, isNull);
    expect(const SearchQuery().inLabel(trashLabelId).isEmpty, isTrue);
    expect(const SearchQuery(terms: ['a']).inLabel(trashLabelId).terms, ['a']);
    expect(const SearchQuery().inLabel(trashLabelId).inAccounts({'a'}).labelId, trashLabelId);
  });
}
