import 'dart:ui';

import 'package:flutter/painting.dart' show TextStyle;

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

/// Testo disegnato contiguo su una riga con un solo font: diventa un `RichText` trasparente sopra la `Picture`.
class const TextFragment({
  required final String text,
  required final Offset offset,
  required final double width,
  required final double height,
  required final TextStyle style,

  /// Cosa separa questo frammento dal precedente nel testo copiato: `''`, `' '` o `'\n'`.
  required final String separator,
}) {
  Rect get rect => offset & Size(width, height);
}

/// Un nodo per le Semantics: paragrafo (o parte), titolo, link o immagine.
class const ContentNode({
  required final String label,

  /// Box del contenuto, uno per riga.
  required final List<Rect> rects,

  /// 1..6 per i titoli, 0 altrimenti.
  final int headingLevel = 0,

  /// Destinazione se il nodo è un link.
  final String? href,
  final bool image = false,
}) {
  Rect get bounds => rects.reduce((a, b) => a.expandToInclude(b));
}
