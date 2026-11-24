import 'dart:ui';

import 'package:flutter/painting.dart' show TextStyle;

/// Testo disegnato contiguo su una riga con un solo font: diventa un `RichText` trasparente sopra la `Picture`.
class const TextFragment({
  required final String text,
  required final Offset offset,
  required final double width,
  required final double height,
  required final TextStyle style,

  /// Cosa separa questo frammento dal precedente nel testo copiato: `''`, `' '` o `'\n'`.
  required final String separator,
}) {
  Rect get rect => offset & Size(width, height);
}
