import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The sign of an Account: a rounded square in its color with its initial, so it reads without color too.
/// Decorative unless [label] is given (“Account Lavoro”).
class PostinoAccountMark extends StatelessWidget {
  /// Crea il segno di un Account.
  const PostinoAccountMark({
    super.key,
    required this.color,
    required this.initial,
    this.size = PostinoSize.accountMark,
    this.label,
  });

  /// Colore dell'Account.
  final PostinoAccountColor color;

  /// Iniziale mostrata nel quadrato.
  final String initial;

  /// Lato del quadrato.
  final double size;

  /// Nome accessibile; se nullo il segno è decorativo.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final swatch = context.pc.account(color);
    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: swatch.color, borderRadius: BorderRadius.circular(size * .3)),
      child: SelectionContainer.disabled(
        child: Text(
          initial,
          // A fixed square: the initial keeps its size with dynamic type.
          textScaler: TextScaler.noScaling,
          style: PostinoText.label.copyWith(
            color: swatch.onColor,
            fontSize: math.max(9, (size * .5).roundToDouble()),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
    return label == null
        ? ExcludeSemantics(child: mark)
        : Semantics(
            label: label,
            image: true,
            child: ExcludeSemantics(child: mark),
          );
  }
}

/// What a component needs to draw an Account's mark: its color and initial.
typedef PostinoAccountRef = ({PostinoAccountColor color, String initial});
