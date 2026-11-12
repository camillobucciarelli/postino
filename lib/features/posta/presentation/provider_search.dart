import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/provider_search_use_case.dart';
import '../../../core/domain/result.dart';
import '../../../core/domain/search_query.dart';

/// The state of the search on the Providers for the query of the search screen (#207): who is still being asked,
/// who could not be reached, what was found. A new query (or [clear]) drops it; answers of an older one are ignored.
class ProviderSearch(final ProviderSearchUseCase _useCase) {
  /// The Accounts still being asked.
  final searching = signal<List<Account>>(const []);

  /// The Accounts that did not answer the last time they were asked, with why (offline or too slow, refused,
  /// paused by the Provider).
  final unreachable = signal<List<(Account, Failure)>>(const []);

  /// Whether some Account has a next page («Mostra altri»).
  final hasMore = signal(false);

  /// The Conversazioni found so far, by Account: the search screen lists them with the local results.
  final found = signal<Map<String, Set<String>>>(const {});

  /// [found] as a stream, from its current value: what the local search joins (`SearchRepository.watchLocal`).
  Stream<Map<String, Set<String>>> watchFound() {
    void Function()? stop;
    late final StreamController<Map<String, Set<String>>> out;
    out = StreamController(
      onListen: () => stop = untracked(() => found.subscribe(out.add)),
      onCancel: () {
        stop?.call();
        return out.close();
      },
    );
    return out.stream;
  }

  SearchQuery? _query;
  final _next = <String, (Account, String)>{};
  var _run = 0;

  /// Asks every attivo Account [query] reaches for its first page.
  Future<void> start(SearchQuery query) async {
    clear();
    _query = query;
    final run = _run;
    final accounts = await _useCase.accountsFor(query);
    if (run == _run) await _ask(accounts, const {});
  }

  /// Asks the Accounts with a next page for it.
  Future<void> more() async {
    if (_next.isEmpty || searching.value.isNotEmpty) return;
    final next = {..._next};
    _next.clear();
    // The button stays while the page loads: the focus stays on it.
    await _ask(
      [for (final (a, _) in next.values) a],
      {for (final MapEntry(:key, :value) in next.entries) key: value.$2},
    );
  }

  /// Forgets the search: the query changed.
  void clear() {
    _run++;
    _query = null;
    _next.clear();
    batch(() {
      searching.value = const [];
      unreachable.value = const [];
      hasMore.value = false;
      found.value = const {};
    });
  }

  Future<void> _ask(List<Account> accounts, Map<String, String> tokens) async {
    final run = _run;
    final query = _query;
    if (query == null) return;
    batch(() {
      searching.value = accounts;
      unreachable.value = [
        for (final u in unreachable.value)
          if (!accounts.contains(u.$1)) u,
      ];
    });
    await for (final (:account, :result) in _useCase.search(accounts, query, pageTokens: tokens)) {
      if (run != _run) return;
      batch(() {
        searching.value = [
          for (final a in searching.value)
            if (a != account) a,
        ];
        switch (result) {
          case Ok(:final value):
            found.value = {
              ...found.value,
              account.id: {...?found.value[account.id], ...value.conversationIds},
            };
            if (value.nextPageToken case final token?) _next[account.id] = (account, token);
          case Err(:final failure):
            unreachable.value = [...unreachable.value, (account, failure)];
            // A page that failed for a passing reason stays to ask again with «Mostra altri»; what was found so far
            // stays too. Not for an Account gone or Da ricollegare: asking again could only fail the same way.
            if (tokens[account.id] case final token? when failure is! AuthFailure && failure is! NotFoundFailure) {
              _next[account.id] = (account, token);
            }
        }
        if (searching.value.isEmpty) hasMore.value = _next.isNotEmpty;
      });
    }
  }

  /// Releases the signals.
  void dispose() {
    _run++;
    for (final s in [searching, unreachable, hasMore, found]) {
      s.dispose();
    }
  }
}
