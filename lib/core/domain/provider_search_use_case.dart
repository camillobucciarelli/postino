import 'dart:async';

import 'package:injectable/injectable.dart';

import 'account.dart';
import 'accounts_repository.dart';
import 'mail_sync.dart';
import 'provider_search_page.dart';
import 'result.dart';
import 'search_query.dart';

/// How long one page of one Account may take before it counts as not reachable (#207); the others go on.
const providerSearchTimeout = Duration(seconds: 15);

/// The answer of one Account's Provider to a search.
typedef ProviderAnswer = ({Account account, Result<ProviderSearchPage> result});

/// The search on the Providers (#207), started with Invio: every attivo Account the query reaches, in parallel, each
/// with its [providerSearchTimeout]. What they find is stored by the sync engine and read from the database.
@injectable
class ProviderSearchUseCase(
  final AccountsRepository _accounts,
  final MailSync _sync, {
  @ignoreParam final Duration timeout = providerSearchTimeout,
}) {
  /// Legge gli Account e chiede ai loro Provider.
  this;

  /// The Accounts [query] reaches, as the local search reads it: those of its `accountIds` (all when empty) whose
  /// address holds one of its `accountNames` (any when empty), attivo only; a Da ricollegare one is not asked.
  Future<List<Account>> accountsFor(SearchQuery query) async => [
    for (final a in await _accounts.watchAccounts().first)
      if (a.status == AccountStatus.attivo &&
          (query.accountIds.isEmpty || query.accountIds.contains(a.id)) &&
          (query.accountNames.isEmpty ||
              query.accountNames.any((n) => a.address.toLowerCase().contains(n.toLowerCase()))))
        a,
  ];

  /// Asks each of [accounts] for one page of [query], from its token in [pageTokens] (none: the first), and gives
  /// each answer as it comes; one slower than the timeout is an [OfflineFailure]. Ends after the last.
  Stream<ProviderAnswer> search(
    List<Account> accounts,
    SearchQuery query, {
    Map<String, String> pageTokens = const {},
  }) {
    final out = StreamController<ProviderAnswer>();
    unawaited(
      Future.wait([
        for (final a in accounts)
          _sync
              .search(a.id, query, pageToken: pageTokens[a.id])
              .timeout(timeout, onTimeout: () => const Err(OfflineFailure()))
              .then((r) => out.isClosed ? null : out.add((account: a, result: r))),
      ]).whenComplete(out.close),
    );
    return out.stream;
  }
}
