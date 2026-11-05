/// The embedding model that runs on the device (ADR 0015): a text becomes a vector, compared by cosine.
/// The real one in core/data; a deterministic one in tests.
abstract interface class TextEmbedder() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Which model makes the vectors: a vector saved by another model is not comparable and is ignored.
  String get modelId;

  /// The vector of [text]; null while the model is not ready (not downloaded, not loaded).
  Future<List<double>?> embed(String text);
}
