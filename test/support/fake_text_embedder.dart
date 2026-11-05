import 'dart:async';

import 'package:postino/core/domain/text_embedder.dart';

/// The embedding model of the tests: each test says the vector of each text.
class FakeTextEmbedder() implements TextEmbedder {
  /// The vector of a text; null, the default, is a model not ready.
  FutureOr<List<double>?> Function(String text) vectorOf = (_) => null;

  /// Every text embedded, in order.
  final texts = <String>[];

  @override
  String get modelId => 'fake';

  @override
  Future<List<double>?> embed(String text) async {
    texts.add(text);
    return await vectorOf(text);
  }
}
