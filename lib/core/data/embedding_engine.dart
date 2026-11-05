/// An embedding model loaded in memory: the seam between `OnDeviceTextEmbedder` and llamadart, so tests use a fake.
/// The real one is `LlamadartEmbeddingEngine`.
abstract interface class EmbeddingEngine() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The tokens the task prefix and the special tokens add to every text.
  int get reservedTokens;

  /// The tokens of [text], special ones excluded; null when the model exposes no tokenizer (`.litertlm`).
  Future<List<int>?> tokenize(String text);

  /// The text of [tokens].
  Future<String> detokenize(List<int> tokens);

  /// The vector of [text] as a classification query: 768 dimensions, L2-normalised.
  Future<List<double>> embed(String text);

  /// Frees the model's memory; the engine is not used again.
  Future<void> dispose();
}

/// Loads the model file at the path into an [EmbeddingEngine]; throws when it cannot.
typedef EmbeddingEngineLoader = Future<EmbeddingEngine> Function(String path);
