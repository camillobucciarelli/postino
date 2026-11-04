import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';
import 'postino_icon.dart';

/// A command with only an icon; [label] is its accessible name and tooltip.
class const PostinoIconButton({super.key, required this.icon, required this.label, required this.onPressed})
    extends StatelessWidget {
  /// Crea un comando con la sola icona.
  this;

  /// Icona del comando.
  final PostinoIconData icon;

  /// Nome accessibile e tooltip.
  final String label;

  /// Chiamata al tocco; se nulla il comando è disabilitato.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    // A bar hands its leading and actions the full toolbar square (tight): the button would fill it
    // and its ring, `focus-offset` outside, would fall outside the bar and be clipped.
    widthFactor: 1,
    heightFactor: 1,
    child: IconButton(
      onPressed: onPressed,
      tooltip: label,
      color: context.pc.inkMuted,
      style: ButtonStyle(
        backgroundBuilder: (context, states, child) =>
            PostinoFocusRing(borderRadius: BorderRadius.circular(PostinoRadius.full), child: child!),
      ),
      icon: PostinoIcon(icon, size: PostinoSize.iconLg),
    ),
  );
}
