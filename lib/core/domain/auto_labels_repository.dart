import 'auto_label.dart';

/// The Etichette automatiche of each Account: an Impostazione di Postino (ADR 0004, extended by ADR 0015).
abstract interface class AutoLabelsRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// By Etichetta id, the Etichette of [accountId] ever set up; an Etichetta missing here is not automatica.
  Stream<Map<String, AutoLabel>> watch(String accountId);

  /// The «Automatica» switch; the description is kept when it is turned off. Turning it on stamps the activation
  /// (now), turning it off clears it.
  Future<void> setAutomatic(String accountId, String labelId, {required bool automatic});

  /// «Descrizione (facoltativa)»: trimmed, blank removes it.
  Future<void> setDescription(String accountId, String labelId, String? description);
}
