import 'package:injectable/injectable.dart';

import '../domain/text_embedder.dart';

/// The embedding model until its adapter arrives (llamadart, the follow-up of #109): never ready, so the
/// Etichettatura automatica classifies nothing.
@LazySingleton(as: TextEmbedder, env: [Environment.prod])
class const UnreadyTextEmbedder() implements TextEmbedder {
  @override
  String get modelId => 'none';

  @override
  Future<List<double>?> embed(String text) async => null;
}
