// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';
import 'postino_icon.dart';

/// Aspetto di un `PostinoButton`.
enum PostinoButtonVariant() {
  /// Pieno: l'azione principale.
  primary,

  /// Solo testo: azione secondaria.
  ghost,
}

/// Altezza di un `PostinoButton`.
enum PostinoButtonSize() {
  /// Compatto.
  sm,

  /// Standard.
  md,

  /// Grande.
  lg,
}

/// A command; [label] is a verb with only the first letter capitalised.
class const PostinoButton({
  super.key,

  /// Verbo mostrato nel pulsante.
  required final String label,

  /// Chiamata al tocco; se nulla il pulsante è disabilitato.
  required final VoidCallback? onPressed,

  /// Aspetto del pulsante.
  final PostinoButtonVariant variant = PostinoButtonVariant.primary,

  /// Altezza del pulsante.
  final PostinoButtonSize size = PostinoButtonSize.md,

  /// A ghost on a tinted surface (Banner) reads as a link.
  final bool underline = false,

  /// Takes the focus when it first appears: the safe answer of a dialog, so Enter picks it.
  final bool autofocus = false,

  /// Lets the caller move the focus here, e.g. to the next row after a resolution.
  final FocusNode? focusNode,

  /// Icona prima del verbo, solo per la variante piena (Rispondi nella barra in basso).
  final PostinoIconData? icon,
}) extends StatelessWidget {
  /// Crea un pulsante.
  this;

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
    return switch ((variant, icon)) {
      (PostinoButtonVariant.primary, null) => FilledButton(
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        style: style,
        child: child,
      ),
      (PostinoButtonVariant.primary, final glyph?) => FilledButton.icon(
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        style: style,
        icon: PostinoIcon(glyph),
        label: child,
      ),
      (PostinoButtonVariant.ghost, _) => TextButton(
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        style: style,
        child: child,
      ),
    };
  }
}
