import 'package:flutter/widgets.dart';

import '../tokens/postino_tokens.dart';

/// The buttons at the bottom of a showPostinoDialog, the primary last; they wrap on a narrow window or large text.
class const PostinoDialogActions({
  super.key,

  /// I pulsanti, l'azione principale per ultima.
  required final List<Widget> children,
}) extends StatelessWidget {
  /// Crea la fila delle azioni.
  this;

  @override
  Widget build(BuildContext context) =>
      Wrap(alignment: WrapAlignment.end, spacing: PostinoSpacing.s2, runSpacing: PostinoSpacing.s2, children: children);
}
