import 'inbox_repository.dart';
import 'search_query.dart';

/// Cerca nella posta già scaricata, solo dal database locale (ADR 0003).
abstract interface class SearchRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Una riga per Conversazione con almeno un messaggio che corrisponde a [query] (negli Account di
  /// `query.accountIds`, o in tutti), la più recente prima; si riemette a ogni scrittura. Una ricerca vuota non
  /// trova niente.
  Stream<List<InboxEntry>> watchLocal(SearchQuery query);
}
