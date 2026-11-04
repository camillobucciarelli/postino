// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
import 'package:flutter/material.dart';

/// Densità della lista: Comfortable (default) e Compact.
@immutable
class PostinoDensity extends ThemeExtension<PostinoDensity> {
  const PostinoDensity({
    required this.rowHeight,
    required this.padY,
    required this.avatar,
    required this.previewLines,
    required this.gap,
  });
  final double rowHeight;
  final double padY;
  final double avatar;
  final double gap;
  final int previewLines;

  static const comfortable = PostinoDensity(
    rowHeight: 88,
    padY: 12,
    avatar: 40,
    previewLines: 1,
    gap: 12,
  );
  static const compact = PostinoDensity(
    rowHeight: 60,
    padY: 8,
    avatar: 0,
    previewLines: 0,
    gap: 8,
  );

  /// Compact col puntatore (desktop).
  static const compactPointer = PostinoDensity(
    rowHeight: 40,
    padY: 8,
    avatar: 0,
    previewLines: 0,
    gap: 8,
  );

  @override
  PostinoDensity copyWith({
    double? rowHeight,
    double? padY,
    double? avatar,
    int? previewLines,
    double? gap,
  }) => PostinoDensity(
    rowHeight: rowHeight ?? this.rowHeight,
    padY: padY ?? this.padY,
    avatar: avatar ?? this.avatar,
    previewLines: previewLines ?? this.previewLines,
    gap: gap ?? this.gap,
  );

  @override
  PostinoDensity lerp(PostinoDensity? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
