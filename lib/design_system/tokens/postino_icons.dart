// postino_icons.dart — the Icon set of the design system: 24×24 stroke paths, 1.6 wide, round caps and joins.
// ponytail: SVG paths drawn by PostinoIcon, not a generated icon font (no font tooling in the repo);
// generate a font from the same paths if raster-free text-like icons are ever needed.
import 'package:flutter/foundation.dart';

/// One icon: the SVG `d` strings of its strokes on a 24×24 grid.
@immutable
class PostinoIconData {
  const PostinoIconData(this.paths);
  final List<String> paths;
}

/// Only the icons the screens use so far; copy more from the Icon card when needed.
abstract final class PostinoIcons {
  static const inbox = PostinoIconData([
    'M3 13l2.5-8h13L21 13v6H3z',
    'M3 13h5l1.5 2.5h5L16 13h5',
  ]);
  static const inboxAll = PostinoIconData([
    'M3 15l2-6h14l2 6v5H3z',
    'M3 15h5l1.5 2h5l1.5-2h5',
    'M6 6h12',
    'M8 3h8',
  ]);
  static const tag = PostinoIconData([
    'M3.5 12.5V4h8.5l8.5 8.5-8.5 8.5z',
    'M8 7.5h.01',
  ]);
  static const star = PostinoIconData([
    'M12 3.5l2.6 5.3 5.9.9-4.25 4.1 1 5.8L12 16.9l-5.25 2.7 1-5.8L3.5 9.7l5.9-.9z',
  ]);
  static const key = PostinoIconData([
    'M8 8a4 4 0 1 0 0 8 4 4 0 1 0 0-8z',
    'M12 12h8.5',
    'M18.5 12v3',
    'M15.5 12v2.5',
  ]);
  static const cloudOff = PostinoIconData([
    'M7 18h10.5a3.5 3.5 0 0 0 1-6.85',
    'M16 7.6A6 6 0 0 0 6.1 10.6 4 4 0 0 0 7 18',
    'M4 4l16 16',
  ]);
  static const refresh = PostinoIconData([
    'M19.5 12a7.5 7.5 0 1 1-2.2-5.3',
    'M19.5 4.5v4h-4',
  ]);
  static const alert = PostinoIconData([
    'M12 3.5L21.5 20h-19z',
    'M12 10v4',
    'M12 17h.01',
  ]);
  static const check = PostinoIconData(['M5 12.5l4.5 4.5L19 7.5']);
  static const menu = PostinoIconData(['M4 7h16', 'M4 12h16', 'M4 17h16']);
  static const sidebar = PostinoIconData(['M4 5h16v14H4z', 'M9 5v14']);
  static const arrowLeft = PostinoIconData(['M20 12H4', 'M10 6l-6 6 6 6']);
  static const chevronDown = PostinoIconData(['M6 9.5l6 6 6-6']);
  static const chevronLeft = PostinoIconData(['M14.5 6l-6 6 6 6']);
  static const important = PostinoIconData(['M4 5h11l5 7-5 7H4l4-7z']);
  static const more = PostinoIconData([
    'M5.5 12h.01',
    'M12 12h.01',
    'M18.5 12h.01',
  ]);
  static const download = PostinoIconData([
    'M12 4v11',
    'M7 10l5 5 5-5',
    'M5 20h14',
  ]);
  static const close = PostinoIconData(['M6 6l12 12', 'M18 6L6 18']);
  static const moreVertical = PostinoIconData([
    'M12 5.5h.01',
    'M12 12h.01',
    'M12 18.5h.01',
  ]);
  // ponytail: drawn here in the set's style, not copied from the Icon card; swap in the card's when it differs.
  static const image = PostinoIconData([
    'M4 5h16v14H4z',
    'M4 16l4.5-4.5 4 4 3-3L20 17',
    'M15.5 9h.01',
  ]);
}
