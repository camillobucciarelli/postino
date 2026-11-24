import 'content_node.dart';
import 'text_fragment.dart';

export 'content_node.dart';
export 'text_fragment.dart';

/// Testo e struttura di un documento dopo il layout, in ordine di documento.
///
/// È tutto in Dart: resta valido dopo `LitehtmlDocument.dispose`, quando del documento resta solo la `Picture`.
/// Serve alla selezione ([fragments]) e alle Semantics e alla tastiera ([nodes]).
class const LitehtmlContent({required final List<TextFragment> fragments, required final List<ContentNode> nodes}) {
  /// Contenuto vuoto (documento fallito o senza testo).
  static const empty = LitehtmlContent(fragments: [], nodes: []);

  /// Link in ordine di documento.
  Iterable<ContentNode> get links => nodes.where((n) => n.href != null);

  /// Tutto il testo come lo copia la selezione completa.
  String get plainText => fragments.indexed.map((e) => e.$1 == 0 ? e.$2.text : e.$2.separator + e.$2.text).join();
}
