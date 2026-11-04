import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';
import 'postino_icon.dart';

/// The extended «Scrivi» button: `fab-bg`, `fab-fg`, `radius-lg`, `fab-height`.
// ponytail: a FilledButton, not FloatingActionButton (no ButtonStyle, so no place for the focus ring).
class const PostinoFab({
  super.key,

  /// Testo del pulsante, anche tooltip.
  required final String label,

  /// Icona a sinistra del testo.
  required final PostinoIconData icon,

  /// Chiamata al tocco.
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  /// Crea il pulsante «Scrivi».
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return FilledButton.icon(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(c.fabBg),
        foregroundColor: WidgetStatePropertyAll(c.fabFg),
        elevation: const WidgetStatePropertyAll(3),
        minimumSize: const WidgetStatePropertyAll(Size(PostinoSize.fabHeight, PostinoSize.fabHeight)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: PostinoSpacing.s5)),
        textStyle: const WidgetStatePropertyAll(PostinoText.label),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.lg))),
        ),
        backgroundBuilder: (context, states, child) =>
            PostinoFocusRing(borderRadius: BorderRadius.circular(PostinoRadius.lg), child: child!),
      ),
      icon: PostinoIcon(icon, size: PostinoSize.iconLg),
      label: Tooltip(
        message: label,
        child: SelectionContainer.disabled(child: Text(label)),
      ),
    );
  }
}
