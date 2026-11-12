import 'package:equatable/equatable.dart';

/// Una ricerca nella posta, a prescindere da dove gira (indice locale, Provider): ogni adattatore la traduce nel suo
/// dialetto (`docs/research/ricerca-server-per-provider.md`). Modello volutamente povero.
class const SearchQuery({
  /// Testo libero: ogni parola deve comparire (AND), anche solo come inizio di parola.
  final List<String> terms = const [],

  /// Frase esatta, scritta tra virgolette.
  final String? phrase,

  /// Il mittente (indirizzo o nome).
  final String? from,

  /// I destinatari (A e Cc).
  final String? to,

  /// L'oggetto.
  final String? subject,

  /// Dal giorno [after], secondo il giorno locale dell'utente (criterio di #206).
  final DateTime? after,

  /// Fino al giorno [before], secondo il giorno locale dell'utente (criterio di #206).
  final DateTime? before,

  /// Solo non letti (criterio di #206).
  final bool? unread,

  /// Solo con Stella (criterio di #206).
  final bool? starred,

  /// Solo con allegati (criterio di #206).
  final bool? hasAttachment,

  /// Gli Account in cui cercare; vuoto: tutti.
  final Set<String> accountIds = const {},
}) extends Equatable {
  /// Crea una ricerca; senza argomenti è vuota.
  this;

  /// Niente da cercare: nessuna parola, frase, mittente, destinatari o oggetto.
  bool get isEmpty => terms.isEmpty && phrase == null && from == null && to == null && subject == null;

  /// La stessa ricerca ristretta a [ids].
  SearchQuery inAccounts(Set<String> ids) => SearchQuery(
    terms: terms,
    phrase: phrase,
    from: from,
    to: to,
    subject: subject,
    after: after,
    before: before,
    unread: unread,
    starred: starred,
    hasAttachment: hasAttachment,
    accountIds: ids,
  );

  @override
  List<Object?> get props => [
    terms,
    phrase,
    from,
    to,
    subject,
    after,
    before,
    unread,
    starred,
    hasAttachment,
    accountIds,
  ];
}
