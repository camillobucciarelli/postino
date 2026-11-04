import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// An indeterminate spinner in `brand`, `icon-md` big, read as [label].
class const PostinoSpinner({
  super.key,

  /// Cosa è in corso, per lo screen reader («Preparazione del modello»).
  required final String label,
}) extends StatelessWidget {
  /// Crea lo spinner.
  this;

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
