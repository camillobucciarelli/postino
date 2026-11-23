import 'package:flutter/widgets.dart';

import '../tokens/postino_icons.dart';

/// One Azione of a PostinoActionBar: an icon button on the bar, or an item of its «more» menu when there is no room.
@immutable
class const PostinoBarAction({
  /// Icona del comando.
  required final PostinoIconData icon,

  /// Nome accessibile, tooltip e voce del menu (un verbo: «Archivia», «Aggiungi Stella»).
  required final String label,

  /// Chiamata al tocco.
  required final VoidCallback onPressed,

  /// Scorciatoia da tastiera («R»), mostrata nel tooltip dopo il nome.
  final String? shortcut,

  /// On the button on the bar: for the tests, or to anchor a popover to it.
  final Key? key,

  /// The button's focus, so a popover it opened can give it back.
  final FocusNode? focusNode,

  /// A toggle that is on (the Stella): its icon filled in the accent.
  final bool selected = false,

  /// When it moves into the «more» menu for lack of room: the lowest first; null, never (Rispondi, Archivia).
  final int? overflow,

  /// The bar's main action: filled, with its [label] beside the icon where a bottom bar has the room.
  final bool primary = false,
}) {
  /// Crea un'Azione della barra.
  this;
}
