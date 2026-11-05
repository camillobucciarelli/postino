// Il modello di embedding sul dispositivo (#135): pronto solo con il file, caricamento pigro che non blocca, testo
// troncato. Motore e gestore dei modelli finti; il motore llamadart vero si verifica a mano (QA).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/embedding_engine.dart';
import 'package:postino/core/data/on_device_text_embedder.dart';
import 'package:postino/core/domain/embedding_models.dart';
import 'package:postino/core/domain/model_state.dart';

import '../../support/fake_model_manager.dart';
import '../../support/fake_platform.dart';

/// One token per word; with `tokenizer` false, none (the `.litertlm`). Each vector is the length of the text.
class _FakeEngine({final bool _tokenizer = true}) implements EmbeddingEngine {
  final texts = <String>[];
  var disposed = false;

  @override
  int get reservedTokens => 6;

  @override
  Future<List<int>?> tokenize(String text) async =>
      _tokenizer ? [for (final w in text.split(' ')) w.length] : null;

  // Detokenizing "loses" nothing but adds a word every 100 tokens, as a real round trip may give a few more.
  @override
  Future<String> detokenize(List<int> tokens) async =>
      [for (var i = 0; i < tokens.length; i++) ...[if (i > 0 && i % 100 == 0) 'x', 'w' * tokens[i]]].join(' ');

  @override
  Future<List<double>> embed(String text) async {
    texts.add(text);
    return [text.length.toDouble()];
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  final model = embeddingGemmaGguf;
  late FakeModelManager manager;
  late FakeErrorLog log;
  late List<Completer<EmbeddingEngine>> loads;
  late OnDeviceTextEmbedder embedder;

  setUp(() {
    manager = FakeModelManager();
    log = FakeErrorLog();
    loads = [];
    embedder = OnDeviceTextEmbedder(manager, model, (path) {
      loads.add(Completer());
      return loads.last.future;
    }, log);
  });

  /// The model on disk and its engine loaded: the first embed starts the load, [engine] finishes it.
  Future<void> ready(EmbeddingEngine engine) async {
    manager.emit(model, const ModelReady('/models/m.gguf'));
    await pumpEventQueue();
    expect(await embedder.embed('primo'), isNull);
    loads.last.complete(engine);
    await pumpEventQueue();
  }

  test('its id is the chosen model', () {
    expect(embedder.modelId, model.id);
  });

  test('null and no load while the model is not on the device', () async {
    for (final state in [
      const ModelAbsent(),
      ModelAwaitingConfirmation(model.sizeBytes),
      ModelDownloading(1, model.sizeBytes),
    ]) {
      manager.emit(model, state);
      await pumpEventQueue();
      expect(await embedder.embed('testo'), isNull);
    }
    expect(loads, isEmpty);
  });

  test('the load is lazy and does not block: null while it runs, one load at a time, then vectors', () async {
    manager.emit(model, const ModelReady('/models/m.gguf'));
    await pumpEventQueue();
    expect(loads, isEmpty, reason: 'nothing loads before the first embed');

    // The load never finishes here: embed still answers at once.
    expect(await embedder.embed('uno'), isNull);
    expect(await embedder.embed('due'), isNull);
    expect(loads, hasLength(1));

    final engine = _FakeEngine();
    loads.single.complete(engine);
    await pumpEventQueue();
    expect(await embedder.embed('tre'), [3.0]);
    expect(engine.texts, ['tre']);
  });

  test('a failed load is in the error log and tried again by a later embed', () async {
    manager.emit(model, const ModelReady('/models/m.gguf'));
    await pumpEventQueue();
    expect(await embedder.embed('uno'), isNull);
    loads.single.completeError(StateError('file rotto'));
    await pumpEventQueue();
    expect(log.entries.single.$1, isA<StateError>());

    expect(await embedder.embed('due'), isNull);
    expect(loads, hasLength(2));
    loads.last.complete(_FakeEngine());
    await pumpEventQueue();
    expect(await embedder.embed('tre'), isNotNull);
  });

  test('the model deleted frees the engine and answers null again', () async {
    final engine = _FakeEngine();
    await ready(engine);
    await manager.delete(model);
    await pumpEventQueue();
    expect(engine.disposed, isTrue);
    expect(await embedder.embed('testo'), isNull);
  });

  test('an engine loaded after its model went is freed, not used', () async {
    manager.emit(model, const ModelReady('/models/m.gguf'));
    await pumpEventQueue();
    await embedder.embed('uno');
    manager.emit(model, const ModelAbsent());
    await pumpEventQueue();
    final engine = _FakeEngine();
    loads.single.complete(engine);
    await pumpEventQueue();
    expect(engine.disposed, isTrue);
    expect(await embedder.embed('due'), isNull);
  });

  test('with a tokenizer the text is cut to 256 tokens, task prefix included', () async {
    final engine = _FakeEngine();
    await ready(engine);
    final short = List.filled(250, 'w').join(' ');
    await embedder.embed(short);
    expect(engine.texts.last, short, reason: '250 + 6 reserved fit');

    await embedder.embed(List.filled(400, 'w').join(' '));
    final cut = (await engine.tokenize(engine.texts.last))!;
    // The first round trip gives 252 tokens: cut again by the excess.
    expect(cut.length, 250);
  });

  test('without a tokenizer (.litertlm) the text is cut to 850 characters', () async {
    final engine = _FakeEngine(tokenizer: false);
    await ready(engine);
    await embedder.embed('a' * 851);
    expect(engine.texts.last, 'a' * maxEmbeddingChars);
    await embedder.embed('a' * 300);
    expect(engine.texts.last, 'a' * 300);
  });

  test('without a tokenizer the UTF-8 bytes are capped too, never splitting a character', () async {
    final engine = _FakeEngine(tokenizer: false);
    await ready(engine);
    // 3 bytes each: 320 of them are 960 bytes.
    await embedder.embed('€' * 400);
    expect(engine.texts.last, '€' * (maxEmbeddingBytes ~/ 3));
    // An emoji is two UTF-16 units and four bytes: never cut in half.
    await embedder.embed('${'a' * 849}😀');
    expect(engine.texts.last, 'a' * 849);
  });
}
