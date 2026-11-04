import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The quoted text once shown: a `border-strong` rule on its left, `body-quote` in `ink-muted`.
class const PostinoQuote(
  /// The quoted text.
  final Widget child, {
  super.key,
}) extends StatelessWidget {
  /// Crea la citazione che racchiude `child`.
  this;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PostinoSpacing.s1),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: context.pc.borderStrong,
            // The DS card's 2px rule: the focus ring is the system's 2px stroke.
            width: PostinoBorder.borderWidthFocus,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: PostinoSpacing.s3),
        child: child,
      ),
    ),
  );
}
