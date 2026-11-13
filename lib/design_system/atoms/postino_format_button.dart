// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';
import 'postino_icon.dart';

/// A format toggle of the editor's bar; [label] is its accessible name and tooltip.
class const PostinoFormatButton({
  super.key,

  /// Icona del formato.
  required final PostinoIconData icon,

  /// Nome accessibile e tooltip.
  required final String label,

  /// Se il formato è attivo sulla selezione.
  required final bool active,

  /// Chiamata al tocco.
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  /// Crea un toggle di formato.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return MergeSemantics(
      // The tooltip is semantic help, not the name: the name is the label.
      child: Semantics(
        label: label,
        toggled: active,
        child: IconButton(
          onPressed: onPressed,
          tooltip: label,
          isSelected: active,
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(active ? c.chipBgSelected : Colors.transparent),
            foregroundColor: WidgetStatePropertyAll(active ? c.brand : c.inkMuted),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PostinoRadius.sm))),
            ),
            backgroundBuilder: (context, states, child) =>
                PostinoFocusRing(borderRadius: BorderRadius.circular(PostinoRadius.sm), child: child!),
          ),
          icon: PostinoIcon(icon),
        ),
      ),
    );
  }
}
