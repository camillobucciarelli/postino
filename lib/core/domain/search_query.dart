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

  /// Dal giorno [after] compreso, secondo il giorno locale dell'utente (mezzanotte locale di quel giorno).
  final DateTime? after,

  /// Fino al giorno [before] compreso, secondo il giorno locale dell'utente (mezzanotte locale di quel giorno).
  final DateTime? before,

  /// Solo non letti: una Conversazione conta se almeno un suo messaggio non è letto.
  final bool? unread,

  /// Solo con Stella: una Conversazione conta se almeno un suo messaggio ha la Stella.
  final bool? starred,

  /// Solo con allegati: un messaggio di cui non si sa ancora se ne ha non conta.
  final bool? hasAttachment,

  /// Nomi (parti dell'indirizzo) degli Account in cui cercare, scritti dall'utente: basta che ne corrisponda uno.
  /// Vuoto: nessuna restrizione.
  final List<String> accountNames = const [],

  /// Gli id degli Account in cui cercare, decisi dal chiamante (la vista da cui si apre la ricerca); vuoto: tutti.
  final Set<String> accountIds = const {},

  /// L'Etichetta della vista da cui si apre la ricerca, decisa dal chiamante (mai scritta dall'utente): solo
  /// `trashLabelId` conta. Con il Cestino si cercano solo i suoi messaggi; altrimenti il Cestino è escluso.
  final String? labelId,
}) extends Equatable {
  /// Crea una ricerca; senza argomenti è vuota.
  this;

  /// Niente da cercare né da filtrare. [accountIds] non conta: è la vista da cui si cerca, non un criterio scritto.
  bool get isEmpty =>
      !hasText &&
      after == null &&
      before == null &&
      unread == null &&
      starred == null &&
      hasAttachment == null &&
      accountNames.isEmpty;

  /// Se c'è qualcosa che l'indice full-text possa cercare (parole, frase, mittente, destinatari, oggetto).
  bool get hasText => terms.isNotEmpty || phrase != null || from != null || to != null || subject != null;

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
    accountNames: accountNames,
    accountIds: ids,
    labelId: labelId,
  );

  /// La stessa ricerca ristretta all'Etichetta [id].
  SearchQuery inLabel(String? id) => SearchQuery(
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
    accountNames: accountNames,
    accountIds: accountIds,
    labelId: id,
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
    accountNames,
    accountIds,
    labelId,
  ];
}
