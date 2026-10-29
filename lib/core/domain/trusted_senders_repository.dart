/// The exact address of a sender, normalized: the one inside `<...>` if any, trimmed, lowercase.
String normalizeAddress(String from) {
  final angle = RegExp(r'<([^<>]*)>\s*$').firstMatch(from);
  return (angle?.group(1) ?? from).trim().toLowerCase();
}

/// Who may load remote resources (ADR 0007): the Mittenti fidati, kept in the database,
/// and the messages shown once, kept in memory for this session.
abstract interface class TrustedSendersRepository {
  /// Normalized addresses ([normalizeAddress]).
  Stream<Set<String>> watchTrusted();

  /// [from] becomes a Mittente fidato: its exact address, not its domain.
  Future<void> trust(String from);

  /// «Mostra immagini»: only this message, until the app closes.
  void showOnce(String accountId, String messageId);
  bool shownOnce(String accountId, String messageId);
}
