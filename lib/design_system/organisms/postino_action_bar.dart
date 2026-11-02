import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The bar of actions under a detail, always in view (the buttons of the Conversazione: Rispondi…):
/// the surface fill, a hairline on top, the [children] wrapping on a narrow window.
class PostinoActionBar extends StatelessWidget {
  const PostinoActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(
            color: c.borderSubtle,
            width: PostinoBorder.borderWidthHairline,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PostinoSpacing.s4,
          vertical: PostinoSpacing.s3,
        ),
        child: Wrap(
          spacing: PostinoSpacing.s2,
          runSpacing: PostinoSpacing.s2,
          children: children,
        ),
      ),
    );
  }
}
