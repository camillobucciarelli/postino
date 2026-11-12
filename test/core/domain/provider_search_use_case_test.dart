import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/provider_search_page.dart';
import 'package:postino/core/domain/provider_search_use_case.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

class _Accounts(final List<Account> all) extends Fake implements AccountsRepository {
  @override
  Stream<List<Account>> watchAccounts() => Stream.value(all);
}

/// Answers each Account after its delay in [slow] (none: at once), with a page holding its id as Conversazione.
class _Sync(final Map<String, Duration> slow) extends Fake implements MailSync {
  final asked = <(String, String?)>[];

  @override
  Future<Result<ProviderSearchPage>> search(String accountId, SearchQuery query, {String? pageToken}) async {
    asked.add((accountId, pageToken));
    await Future<void>.delayed(slow[accountId] ?? Duration.zero);
    return Ok(ProviderSearchPage(conversationIds: {'t-$accountId'}));
  }
}

Account _account(String id, {AccountStatus status = AccountStatus.attivo}) =>
    Account(id: id, address: '$id@example.test', provider: ProviderKind.gmail, color: 0, position: 0, status: status);

void main() {
  const q = SearchQuery(terms: ['fattura']);

  test('only the attivo Accounts the query reaches are asked', () async {
    final use = ProviderSearchUseCase(
      _Accounts([_account('a'), _account('b', status: AccountStatus.daRicollegare), _account('c')]),
      _Sync(const {}),
    );
    expect((await use.accountsFor(q)).map((a) => a.id), ['a', 'c']);
    expect((await use.accountsFor(q.inAccounts({'c'}))).map((a) => a.id), ['c']);
    expect(
      (await use.accountsFor(const SearchQuery(terms: ['fattura'], accountNames: ['C@EXAMPLE']))).map((a) => a.id),
      ['c'],
      reason: 'the `account:` operator, as the local search reads it',
    );
  });

  test('all at once, each answer as it comes; one past the timeout is offline, the others stay', () async {
    final sync = _Sync(const {'slow': Duration(seconds: 5), 'b': Duration(milliseconds: 20)});
    final use = ProviderSearchUseCase(_Accounts(const []), sync, timeout: const Duration(milliseconds: 200));
    final answers = [
      for (final a
          in await use.search([_account('slow'), _account('b'), _account('c')], q, pageTokens: {'b': 'p2'}).toList())
        '${a.account.id}:${a.result is Ok ? 'ok' : (a.result as Err).failure.runtimeType}',
    ];
    expect(sync.asked, [('slow', null), ('b', 'p2'), ('c', null)], reason: 'in parallel, each from its page');
    expect(answers, ['c:ok', 'b:ok', 'slow:OfflineFailure']);
  });

  test('the timeout of a page is 15 s', () => expect(providerSearchTimeout, const Duration(seconds: 15)));
}
