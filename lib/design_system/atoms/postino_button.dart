import 'package:flutter/material.dart';

import '../tokens/postino_tokens.dart';

enum PostinoButtonVariant { primary, ghost }

enum PostinoButtonSize { sm, md, lg }

/// A command; [label] is a verb with only the first letter capitalised.
class PostinoButton extends StatelessWidget {
  const PostinoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PostinoButtonVariant.primary,
    this.size = PostinoButtonSize.md,
    this.underline = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PostinoButtonVariant variant;
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
        (size == PostinoButtonSize.sm ? PostinoText.labelSm : PostinoText.label)
            .copyWith(decoration: underline ? TextDecoration.underline : null),
      ),
    );
    final child = Text(label);
    return switch (variant) {
      PostinoButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      PostinoButtonVariant.ghost => TextButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    };
  }
}
