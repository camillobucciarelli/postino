import 'package:llamadart/llamadart.dart';

import 'embedding_engine.dart';

/// EmbeddingGemma-2 on llamadart (ADR 0015): `.litertlm` on LiteRT-LM (CPU only, no tokenizer), GGUF on llama.cpp.
/// llamadart runs the model in its own worker isolate: no call here blocks the UI.
// ponytail: thin wrapper over llamadart, verified by hand (QA), not by unit tests.
class LlamadartEmbeddingEngine._(final LlamaEngine _engine, final bool _litert, @override final int reservedTokens)
    implements EmbeddingEngine {
  /// The prefix of [LlamaEmbeddingText.query] with [LlamaEmbeddingTask.classification].
  static const _prefix = 'task: classification | query: ';

  /// Loads the model at [path]; the format follows the file's extension.
  static Future<EmbeddingEngine> load(String path) async {
    final litert = path.endsWith('.litertlm');
    final engine = await LlamaEngine.load(
      LlamaModel(ModelSource.path(path)),
      params: litert
          ? const LiteRtLmModelParams(embeddingEngine: true, device: ComputeDevice.cpu, contextSize: 1024)
          : const ModelParams(contextSize: 1024, batchSize: 1024, microBatchSize: 1024),
    );
    // LiteRT-LM in embedding mode refuses the tokenizer: 9 is what the GGUF counts for the same Gemma prefix.
    final reserved = litert ? 9 : (await engine.tokenize(_prefix)).length;
    return LlamadartEmbeddingEngine._(engine, litert, reserved);
  }

  late final _embedder = LlamaTextEmbedder(_engine, profile: LlamaEmbeddingProfile.embeddingGemma2);

  @override
  Future<List<int>?> tokenize(String text) async => _litert ? null : _engine.tokenize(text, addSpecial: false);

  @override
  Future<String> detokenize(List<int> tokens) => _engine.detokenize(tokens);

  @override
  Future<List<double>> embed(String text) =>
      _embedder.embed(LlamaEmbeddingText.query(text, task: LlamaEmbeddingTask.classification));

  @override
  Future<void> dispose() => _engine.dispose();
}
