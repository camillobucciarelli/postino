import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A determinate bar ([value] 0–1) or an indeterminate one (null): `brand` on [track], `radius-full`.
/// Read as [label] with its value in steps of 25% («50%»), so a live region around it (a Banner)
/// speaks at the steps, not at every tick.
class const PostinoProgressBar({
  super.key,

  /// Cosa avanza, per lo screen reader («Download del modello»).
  required final String label,

  /// Avanzamento da 0 a 1; nullo se indeterminato.
  final double? value,

  /// Fondo della barra; di default `border-subtle`.
  final Color? track,
}) extends StatelessWidget {
  /// Crea la barra di avanzamento.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final v = value;
    return Semantics(
      label: label,
      value: v == null ? null : '${(v.clamp(0, 1) * 100) ~/ 25 * 25}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.full)),
          child: LinearProgressIndicator(
            value: v,
            minHeight: PostinoSpacing.s1,
            color: c.brand,
            backgroundColor: track ?? c.borderSubtle,
          ),
        ),
      ),
    );
  }
}
