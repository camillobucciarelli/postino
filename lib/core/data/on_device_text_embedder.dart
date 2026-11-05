import 'dart:async';

import '../domain/error_log.dart';
import '../domain/model_descriptor.dart';
import '../domain/model_manager.dart';
import '../domain/model_state.dart';
import '../domain/text_embedder.dart';
import 'embedding_engine.dart';

/// The tokens of a text the model sees, task prefix included (ADR 0015).
const maxEmbeddingTokens = 256;

/// Without a tokenizer (`.litertlm`), the characters kept: on the spike #103 mail no cut this long went past
/// 256 tokens (the shortest 256-token head was 854 characters; 3.7 characters per token on average, 2.77 at least).
const maxEmbeddingChars = 850;

/// Without a tokenizer, the UTF-8 bytes kept whatever the characters: the Gemma tokenizer makes at most one token
/// per byte, so the input stays under the encoder's 1024 tokens, which LiteRT-LM never truncates (it throws).
const maxEmbeddingBytes = 960;

/// The [TextEmbedder] on the device (#135): the model of [_model] once [ModelManager] has it ready, loaded by
/// [_load] on first use. [embed] waits for the load, which the sync never does: `AutoLabeler` runs outside it, so
/// the mail of the first sync after a launch is classified too.
class OnDeviceTextEmbedder(
  final ModelManager _manager,
  final ModelDescriptor _model,
  final EmbeddingEngineLoader _load,
  final ErrorLog _log,
) implements TextEmbedder {
  this {
    // ignore: cancel_subscriptions, lives as long as the app (a singleton).
    _manager.watch(_model).listen(_onModel);
  }

  /// The model file while [ModelReady], else null.
  String? _path;

  /// Il caricamento di [_path], condiviso da ogni [embed]: uno alla volta. Null se è fallito: non si ritenta fino a
  /// un file nuovo o al prossimo avvio, così un modello che non si carica non viene ricaricato a ogni sync.
  Future<EmbeddingEngine?>? _engine;

  @override
  String get modelId => _model.id;

  @override
  Future<List<double>?> embed(String text) async {
    final path = _path;
    if (path == null) return null;
    final engine = await (_engine ??= _start(path));
    // Il modello è andato o cambiato durante il caricamento: il motore è del file vecchio.
    if (engine == null || _path != path) return null;
    return engine.embed(await _cut(engine, text));
  }

  void _onModel(ModelState state) {
    final path = state is ModelReady ? state.path : null;
    if (path == _path) return;
    _path = path;
    // Deleted or replaced: the loaded engine is the old file's.
    final old = _engine;
    _engine = null;
    if (old != null) unawaited(old.then((engine) => engine?.dispose()));
  }

  Future<EmbeddingEngine?> _start(String path) async {
    try {
      return await _load(path);
    } on Object catch (e, s) {
      _log.record(e, stack: s, context: 'caricamento del modello ${_model.id}');
      return null;
    }
  }

  /// [text] cut to [maxEmbeddingTokens] with the model's tokenizer, or by [maxEmbeddingChars] and
  /// [maxEmbeddingBytes] without one.
  static Future<String> _cut(EmbeddingEngine engine, String text) async {
    final budget = maxEmbeddingTokens - engine.reservedTokens;
    final tokens = await engine.tokenize(text);
    if (tokens == null) return _cutChars(text);
    if (tokens.length <= budget) return text;
    // Detokenizing and tokenizing again may give a few tokens more: cut again by the excess.
    var keep = budget;
    while (keep > 0) {
      final cut = await engine.detokenize(tokens.sublist(0, keep));
      final n = (await engine.tokenize(cut))!.length;
      if (n <= budget) return cut;
      keep -= n - budget;
    }
    return '';
  }

  static String _cutChars(String text) {
    var chars = 0;
    var bytes = 0;
    for (final rune in text.runes) {
      final width = rune < 0x80 ? 1 : (rune < 0x800 ? 2 : (rune < 0x10000 ? 3 : 4));
      final units = rune < 0x10000 ? 1 : 2;
      if (chars + units > maxEmbeddingChars || bytes + width > maxEmbeddingBytes) break;
      chars += units;
      bytes += width;
    }
    return text.substring(0, chars);
  }
}
