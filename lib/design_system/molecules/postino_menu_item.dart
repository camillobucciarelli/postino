import 'package:flutter/foundation.dart';

import '../tokens/postino_icons.dart';

/// One entry of a PostinoMenu or a PostinoContextMenu: [label] (a verb), an optional leading [icon], [onPressed].
class const PostinoMenuItem({
  /// Verbo che dice cosa fa la voce.
  required final String label,

  /// Chiamata alla scelta della voce.
  required final VoidCallback onPressed,

  /// Icona a sinistra, se serve.
  final PostinoIconData? icon,

  /// For the tests, on the item's button.
  final Key? key,

  /// Its keyboard shortcut («⌘R»): the tooltip of a command shown as an icon button says it.
  final String? shortcut,
}) {
  /// Crea una voce di menu.
  this;
}
