import 'dart:ui' as ui;

import 'litehtml_content.dart';

/// `Picture` (con altezza e [LitehtmlContent] per selezione e Semantics) dei documenti usciti dalla vista, senza DOM
/// nativo: rientrando in vista si ridisegnano subito e il DOM
/// si ricrea solo quando serve (link, nuova larghezza).
///
/// LRU per numero di documenti, [maxEntries] (32 di default). Lo spike #66 misurava ~0,2 MB per documento fuori vista
/// contro ~2 MB con il DOM vivo: ~6–7 MB al massimo. Le immagini disegnate restano vive con la loro `Picture` e non
/// sono in quel conto.
// ponytail: limite per numero, non per byte; per byte (`Picture.approximateBytesUsed`) se le immagini pesano.
class LitehtmlPictureCache({final int maxEntries = 32}) {
  /// Quella usata da `LitehtmlView`.
  static final shared = LitehtmlPictureCache();

  /// In ordine di inserimento: la prima è la meno recente.
  final _entries = <(String, double), (ui.Picture, double, LitehtmlContent)>{};

  int get length => _entries.length;

  /// Toglie e restituisce `(picture, altezza, contenuto)` di [html] a [width]: da qui in poi la `Picture` è del chiamante.
  (ui.Picture, double, LitehtmlContent)? take(String html, double width) => _entries.remove((html, width));

  /// Conserva [picture] (di qui in poi della cache) e libera la meno recente oltre [maxEntries].
  void put(String html, double width, ui.Picture picture, double height, LitehtmlContent content) {
    _entries.remove((html, width))?.$1.dispose();
    _entries[(html, width)] = (picture, height, content);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first)!.$1.dispose();
    }
  }

  /// Libera tutte le `Picture`.
  void clear() {
    for (final (picture, _, _) in _entries.values) {
      picture.dispose();
    }
    _entries.clear();
  }
}
