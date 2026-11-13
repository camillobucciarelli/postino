import 'inbox_repository.dart';
import 'search_query.dart';

/// Cerca nella posta già scaricata, solo dal database locale (ADR 0003).
abstract interface class SearchRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Una riga per Conversazione con almeno un messaggio che corrisponde a [query] (negli Account di
  /// `query.accountIds`, o in tutti), la più recente prima; si riemette a ogni scrittura. Una ricerca vuota non
  /// trova niente.
  /// [found] (#207) gives, at each page of the search on the Providers, the Conversazioni found there by Account:
  /// they are rows too, even when the local index does not match them (a word only in a body not downloaded).
  Stream<List<InboxEntry>> watchLocal(SearchQuery query, {Stream<Map<String, Set<String>>>? found});
}
