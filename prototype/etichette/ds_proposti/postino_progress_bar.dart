// PROTOTIPO (#106) — componenti proposti per il design system (atomi).
import 'package:flutter/material.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// A determinate bar ([value] 0–1) or an indeterminate one (null), `brand` on [track] (default surface-pressed;
/// on a brand-subtle Banner pass surface). Read as [label] with [semanticsValue]: pass a stepped value
/// («25%») so a live region around it speaks at the steps, not at every tick.
class const PostinoProgressBar({
  super.key,
  required final String label,
  final double? value,
  final String? semanticsValue,
  final Color? track,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      label: label,
      value: semanticsValue,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PostinoRadius.full),
          child: LinearProgressIndicator(
            value: value,
            minHeight: PostinoSpacing.s1,
            color: c.brand,
            backgroundColor: track ?? c.surfacePressed,
          ),
        ),
      ),
    );
  }
}

/// An indeterminate spinner, `icon-md` big, read as [label].
class const PostinoSpinner({super.key, required final String label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: PostinoSize.iconMd,
        child: CircularProgressIndicator(strokeWidth: PostinoBorder.borderWidthFocus, color: context.pc.brand),
      ),
    ),
  );
}
