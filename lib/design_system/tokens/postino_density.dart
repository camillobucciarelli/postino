// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
import 'package:flutter/material.dart';

/// Densità della lista: Comfortable (default) e Compact.
@immutable
class const PostinoDensity({
  /// Altezza della riga in lista.
  required final double rowHeight,

  /// Padding verticale della riga.
  required final double padY,

  /// Diametro dell'avatar (0 = nascosto).
  required final double avatar,

  /// Righe di anteprima del corpo (0 = nessuna).
  required final int previewLines,

  /// Spazio fra gli elementi della riga.
  required final double gap,
}) extends ThemeExtension<PostinoDensity> {
  /// Crea una densità con tutte le misure esplicite.
  this;

  /// Densità predefinita, più ariosa.
  static const comfortable = PostinoDensity(rowHeight: 88, padY: 12, avatar: 40, previewLines: 1, gap: 12);

  /// Densità compatta, senza avatar né anteprima.
  static const compact = PostinoDensity(rowHeight: 60, padY: 8, avatar: 0, previewLines: 0, gap: 8);

  /// Compact col puntatore (desktop).
  static const compactPointer = PostinoDensity(rowHeight: 40, padY: 8, avatar: 0, previewLines: 0, gap: 8);

  @override
  PostinoDensity copyWith({double? rowHeight, double? padY, double? avatar, int? previewLines, double? gap}) =>
      PostinoDensity(
        rowHeight: rowHeight ?? this.rowHeight,
        padY: padY ?? this.padY,
        avatar: avatar ?? this.avatar,
        previewLines: previewLines ?? this.previewLines,
        gap: gap ?? this.gap,
      );

  @override
  PostinoDensity lerp(PostinoDensity? other, double t) => t < 0.5 ? this : (other ?? this);
}
