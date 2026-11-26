import 'dart:ui';

/// Un nodo per le Semantics: paragrafo (o parte), titolo, link o immagine.
class const ContentNode({
  required final String label,

  /// Box del contenuto, uno per riga.
  required final List<Rect> rects,

  /// 1..6 per i titoli, 0 altrimenti.
  final int headingLevel = 0,

  /// Destinazione se il nodo è un link.
  final String? href,

  /// Livello di pittura di un link: fra link sovrapposti risponde quello col livello più alto (a parità, l'ultimo).
  final int layer = 0,
  final bool image = false,
}) {
  Rect get bounds => rects.reduce((a, b) => a.expandToInclude(b));
}
