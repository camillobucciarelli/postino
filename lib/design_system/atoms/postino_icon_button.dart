// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';
import 'postino_icon.dart';

/// A command with only an icon; [label] is its accessible name and tooltip.
class const PostinoIconButton({
  super.key,

  /// Icona del comando.
  required final PostinoIconData icon,

  /// Nome accessibile e tooltip.
  required final String label,

  /// Chiamata al tocco; se nulla il comando è disabilitato.
  required final VoidCallback? onPressed,

  /// The button's focus, so a popover it opened can give it back on Esc.
  final FocusNode? focusNode,

  /// Its keyboard shortcut («⌘R»), shown in the tooltip after [label]; the screen reader hears only [label].
  final String? shortcut,
}) extends StatelessWidget {
  /// Crea un comando con la sola icona.
  this;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      focusNode: focusNode,
      tooltip: shortcut == null ? label : null,
      color: context.pc.inkMuted,
      style: ButtonStyle(
        backgroundBuilder: (context, states, child) =>
            PostinoFocusRing(borderRadius: BorderRadius.circular(PostinoRadius.full), child: child!),
      ),
      icon: PostinoIcon(icon, size: PostinoSize.iconLg),
    );
    return Center(
      // A bar hands its leading and actions the full toolbar square (tight): the button would fill it
      // and its ring, `focus-offset` outside, would fall outside the bar and be clipped.
      widthFactor: 1,
      heightFactor: 1,
      child: switch (shortcut) {
        null => button,
        final keys => MergeSemantics(
          child: Semantics(
            label: label,
            child: Tooltip(message: '$label · $keys', excludeFromSemantics: true, child: button),
          ),
        ),
      },
    );
  }
}
