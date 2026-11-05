// postino_icons.dart — the Icon set of the design system: 24×24 stroke paths, 1.6 wide, round caps and joins.
// ponytail: SVG paths drawn by PostinoIcon, not a generated icon font (no font tooling in the repo);
// generate a font from the same paths if raster-free text-like icons are ever needed.
import 'package:flutter/foundation.dart';

/// One icon: the SVG `d` strings of its strokes on a 24×24 grid.
@immutable
class const PostinoIconData(
  /// Stringhe `d` SVG, una per tratto.
  final List<String> paths,
) {
  /// Crea un'icona dai tracciati dei suoi tratti.
  this;
}

/// Only the icons the screens use so far; copy more from the Icon card when needed.
abstract final class PostinoIcons() {
  /// Non istanziabile: solo membri statici.
  this;

  /// Posta in arrivo.
  static const inbox = PostinoIconData(['M3 13l2.5-8h13L21 13v6H3z', 'M3 13h5l1.5 2.5h5L16 13h5']);

  /// Tutta la posta.
  static const inboxAll = PostinoIconData(['M3 15l2-6h14l2 6v5H3z', 'M3 15h5l1.5 2h5l1.5-2h5', 'M6 6h12', 'M8 3h8']);

  /// Etichetta.
  static const tag = PostinoIconData(['M3.5 12.5V4h8.5l8.5 8.5-8.5 8.5z', 'M8 7.5h.01']);

  /// Stella (preferiti).
  static const star = PostinoIconData(['M12 3.5l2.6 5.3 5.9.9-4.25 4.1 1 5.8L12 16.9l-5.25 2.7 1-5.8L3.5 9.7l5.9-.9z']);

  /// Chiave.
  static const key = PostinoIconData(['M8 8a4 4 0 1 0 0 8 4 4 0 1 0 0-8z', 'M12 12h8.5', 'M18.5 12v3', 'M15.5 12v2.5']);

  /// Nuvola barrata (offline).
  static const cloudOff = PostinoIconData([
    'M7 18h10.5a3.5 3.5 0 0 0 1-6.85',
    'M16 7.6A6 6 0 0 0 6.1 10.6 4 4 0 0 0 7 18',
    'M4 4l16 16',
  ]);

  /// Aggiorna.
  static const refresh = PostinoIconData(['M19.5 12a7.5 7.5 0 1 1-2.2-5.3', 'M19.5 4.5v4h-4']);

  /// Avviso.
  static const alert = PostinoIconData(['M12 3.5L21.5 20h-19z', 'M12 10v4', 'M12 17h.01']);

  /// Spunta.
  static const check = PostinoIconData(['M5 12.5l4.5 4.5L19 7.5']);

  /// Menu (tre righe).
  static const menu = PostinoIconData(['M4 7h16', 'M4 12h16', 'M4 17h16']);

  /// Barra laterale.
  static const sidebar = PostinoIconData(['M4 5h16v14H4z', 'M9 5v14']);

  /// Freccia a sinistra.
  static const arrowLeft = PostinoIconData(['M20 12H4', 'M10 6l-6 6 6 6']);

  /// Chevron verso il basso.
  static const chevronDown = PostinoIconData(['M6 9.5l6 6 6-6']);

  /// Chevron verso sinistra.
  static const chevronLeft = PostinoIconData(['M14.5 6l-6 6 6 6']);

  /// Importante.
  static const important = PostinoIconData(['M4 5h11l5 7-5 7H4l4-7z']);

  /// Altro (tre puntini orizzontali).
  static const more = PostinoIconData(['M5.5 12h.01', 'M12 12h.01', 'M18.5 12h.01']);

  /// Scarica.
  static const download = PostinoIconData(['M12 4v11', 'M7 10l5 5 5-5', 'M5 20h14']);

  /// Chiudi.
  static const close = PostinoIconData(['M6 6l12 12', 'M18 6L6 18']);

  /// Altro (tre puntini verticali).
  static const moreVertical = PostinoIconData(['M12 5.5h.01', 'M12 12h.01', 'M12 18.5h.01']);
  // ponytail: drawn here in the set's style, not copied from the Icon card; swap in the card's when it differs.
  /// Immagine.
  static const image = PostinoIconData(['M4 5h16v14H4z', 'M4 16l4.5-4.5 4 4 3-3L20 17', 'M15.5 9h.01']);

  /// Matita (scrivi).
  static const pencil = PostinoIconData(['M4 20l1-4.5L16 4.5l3.5 3.5L8.5 19z', 'M13.5 7l3.5 3.5']);

  /// Grassetto.
  static const bold = PostinoIconData(['M7 4.5h6a3.5 3.5 0 0 1 0 7H7z', 'M7 11.5h7a4 4 0 0 1 0 8H7z']);

  /// Corsivo.
  static const italic = PostinoIconData(['M10 4.5h8', 'M6 19.5h8', 'M14.5 4.5l-5 15']);

  /// Sottolineato.
  static const underline = PostinoIconData(['M7 4v7a5 5 0 0 0 10 0V4', 'M5 20h14']);
  // ponytail: strikethrough and listNumbered are not in the Icon card; drawn in its style.
  /// Barrato.
  static const strikethrough = PostinoIconData(['M5 12h14', 'M16.5 7.5a4.5 3 0 0 0-9 0', 'M7.5 16.5a4.5 3 0 0 0 9 0']);

  /// Collegamento.
  static const link = PostinoIconData([
    'M10 14a4 4 0 0 0 5.66 0l3-3a4 4 0 0 0-5.66-5.66l-1 1',
    'M14 10a4 4 0 0 0-5.66 0l-3 3a4 4 0 0 0 5.66 5.66l1-1',
  ]);

  /// Elenco puntato.
  static const listBullet = PostinoIconData([
    'M9 7h11',
    'M9 12h11',
    'M9 17h11',
    'M4.5 7h.01',
    'M4.5 12h.01',
    'M4.5 17h.01',
  ]);

  /// Elenco numerato.
  static const listNumbered = PostinoIconData([
    'M10 7h10',
    'M10 12h10',
    'M10 17h10',
    'M3.5 5.5l1.5-1v4.5',
    'M3 14a1.5 1.5 0 1 1 3 1l-3 3h3',
  ]);

  /// Invia.
  static const send = PostinoIconData(['M4 12l16-8-6 16-2.5-6.5z', 'M11.5 13.5L20 4']);

  // ponytail: plus, search, settings and chevronRight are not in the Icon card; drawn in its style.
  /// Più (crea, aggiungi).
  static const plus = PostinoIconData(['M12 5v14', 'M5 12h14']);

  /// Cerca.
  static const search = PostinoIconData(['M10.5 4a6.5 6.5 0 1 0 0 13 6.5 6.5 0 1 0 0-13z', 'M15.5 15.5L20 20']);

  /// Impostazioni (ingranaggio).
  static const settings = PostinoIconData([
    'M19.03 10.43L21.21 10.7L21.21 13.3L19.03 13.57L18.08 15.86L19.43 17.59L17.59 19.43L15.86 18.08L13.57 19.03 '
        'L13.3 21.21L10.7 21.21L10.43 19.03L8.14 18.08L6.41 19.43L4.57 17.59L5.92 15.86L4.97 13.57L2.79 13.3 '
        'L2.79 10.7L4.97 10.43L5.92 8.14L4.57 6.41L6.41 4.57L8.14 5.92L10.43 4.97L10.7 2.79L13.3 2.79L13.57 4.97 '
        'L15.86 5.92L17.59 4.57L19.43 6.41L18.08 8.14z',
    'M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z',
  ]);

  /// Chevron verso destra.
  static const chevronRight = PostinoIconData(['M9.5 6l6 6-6 6']);
}
