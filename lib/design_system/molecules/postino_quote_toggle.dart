import 'package:flutter/material.dart';

import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Of `PostinoThreadMessage` only (not in the barrel).
/// «…»: shows or hides the quoted text. A `surface-pressed` pill 32×20, in a 48 high target.
class PostinoQuoteToggle extends StatelessWidget {
  /// Crea il pulsante «…» per mostrare o nascondere la citazione.
  const PostinoQuoteToggle({super.key, required this.label, required this.open, required this.onTap});

  /// Its name for screen readers («Mostra il testo citato»).
  final String label;

  /// Whether the quote is shown.
  final bool open;

  /// Shows or hides the quote.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(child: _toggle(context));

  Widget _toggle(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      expanded: open,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      // The 48 box is the tap area; hover and focus hug the pill.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: PostinoSize.touchTargetAndroid,
          height: PostinoSize.touchTargetAndroid,
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              key: const ValueKey('quote-toggle'),
              onTap: onTap,
              borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.xs)),
              child: PostinoFocusRing(
                borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.xs)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfacePressed,
                    borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.xs)),
                  ),
                  child: SizedBox(
                    width: PostinoSize.controlSm,
                    height: PostinoSize.iconMd,
                    child: Center(
                      child: PostinoIcon(PostinoIcons.more, size: PostinoSize.iconSm, color: c.inkMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
