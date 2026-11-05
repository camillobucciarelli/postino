/// Why the name of a new Etichetta is refused.
enum LabelNameError() {
  /// Nessun nome.
  empty,

  /// Un livello senza nome: «Progetti/», «/Postino», «Progetti//Postino».
  emptyLevel,

  /// Esiste già un'Etichetta con questo nome, ignorando le maiuscole.
  duplicate,
}

/// The error that refuses [name] for a new Etichetta among the [existing] names, null when it is valid.
/// «/» separates the levels of a nested Etichetta, as on Gmail; spaces around the name do not count.
LabelNameError? labelNameError(String name, Iterable<String> existing) {
  final n = name.trim();
  if (n.isEmpty) return LabelNameError.empty;
  if (n.split('/').any((level) => level.trim().isEmpty)) return LabelNameError.emptyLevel;
  final lower = n.toLowerCase();
  if (existing.any((e) => e.trim().toLowerCase() == lower)) return LabelNameError.duplicate;
  return null;
}
