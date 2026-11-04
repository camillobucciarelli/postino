import 'package:flutter/material.dart';

import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';

/// Aspetto di un `PostinoButton`.
enum PostinoButtonVariant {
  /// Pieno: l'azione principale.
  primary,

  /// Solo testo: azione secondaria.
  ghost,
}

/// Altezza di un `PostinoButton`.
enum PostinoButtonSize {
  /// Compatto.
  sm,

  /// Standard.
  md,

  /// Grande.
  lg,
}

/// A command; [label] is a verb with only the first letter capitalised.
class PostinoButton extends StatelessWidget {
  /// Crea un pulsante.
  const PostinoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PostinoButtonVariant.primary,
    this.size = PostinoButtonSize.md,
    this.underline = false,
  });

  /// Verbo mostrato nel pulsante.
  final String label;

  /// Chiamata al tocco; se nulla il pulsante è disabilitato.
  final VoidCallback? onPressed;

  /// Aspetto del pulsante.
  final PostinoButtonVariant variant;

  /// Altezza del pulsante.
  final PostinoButtonSize size;

  /// A ghost on a tinted surface (Banner) reads as a link.
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final (height, pad) = switch (size) {
      PostinoButtonSize.sm => (PostinoSize.controlSm, PostinoSpacing.s3),
      PostinoButtonSize.md => (PostinoSize.controlMd, PostinoSpacing.s4),
      PostinoButtonSize.lg => (PostinoSize.controlLg, PostinoSpacing.s6),
    };
    // Only the size here: colors come from the theme, so a container (Banner) can restyle a ghost.
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(64, height)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: pad)),
      textStyle: WidgetStatePropertyAll(
        (size == PostinoButtonSize.sm ? PostinoText.labelSm : PostinoText.label).copyWith(
          decoration: underline ? TextDecoration.underline : null,
        ),
      ),
      // The filled button is `radius-sm` (theme), the ghost a stadium (M3 TextButton).
      backgroundBuilder: (context, states, child) => PostinoFocusRing(
        borderRadius: BorderRadius.circular(
          variant == PostinoButtonVariant.primary ? PostinoRadius.sm : PostinoRadius.full,
        ),
        child: child!,
      ),
    );
    // Buttons are controls, not content: out of any selection.
    final child = SelectionContainer.disabled(child: Text(label));
    return switch (variant) {
      PostinoButtonVariant.primary => FilledButton(onPressed: onPressed, style: style, child: child),
      PostinoButtonVariant.ghost => TextButton(onPressed: onPressed, style: style, child: child),
    };
  }
}
