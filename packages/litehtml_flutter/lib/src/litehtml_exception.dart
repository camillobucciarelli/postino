/// Perché litehtml non ha reso un documento.
enum LitehtmlFailure() {
  /// HTML oltre il limite di byte del motore.
  tooLarge,

  /// HTML con troppi elementi aperti uno dentro l'altro.
  tooDeep,

  /// Il motore ha rifiutato il documento (eccezione o budget di celle esaurito).
  failed,

  /// Layout fallito o budget di lavoro esaurito (es. tabelle annidate in profondità).
  layout,
}

/// Errore gestito di litehtml: il chiamante ripiega su un altro modo di mostrare l'HTML.
class const LitehtmlException(final LitehtmlFailure failure) implements Exception {
  @override
  String toString() => 'LitehtmlException: ${failure.name}';
}
