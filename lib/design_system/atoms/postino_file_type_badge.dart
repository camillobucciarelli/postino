// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_icon.dart';

/// The type of an attached file, for `PostinoAttachmentChip` only (not in the barrel).
/// 40 square, `radius-sm`: the extension (up to 4 letters) or the image icon, colored by kind.
class const PostinoFileTypeBadge(
  /// The file name; its extension picks the kind and the label.
  final String name, {
  super.key,
}) extends StatelessWidget {
  /// Crea il badge del tipo del file `name`.
  this;

  static final _kinds = {
    'pdf': _Kind.pdf,
    for (final e in ['doc', 'docx', 'odt', 'rtf', 'txt', 'pages']) e: _Kind.doc,
    for (final e in ['xls', 'xlsx', 'ods', 'csv', 'numbers']) e: _Kind.sheet,
    for (final e in ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp', 'tif', 'tiff', 'svg']) e: _Kind.image,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 && dot < name.length - 1 ? name.substring(dot + 1).toLowerCase() : '';
    final kind = _kinds[ext] ?? _Kind.other;
    final (bg, fg) = switch (kind) {
      _Kind.pdf => (c.dangerSubtle, c.danger),
      _Kind.doc => (c.brandSubtle, c.brand),
      _Kind.sheet => (c.successSubtle, c.success),
      _Kind.image => (c.labelSeaBg, c.labelSeaFg),
      _Kind.other => (c.surfacePressed, c.inkMuted),
    };
    final label = (ext.isEmpty ? 'file' : ext).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: PostinoSize.controlMd,
        height: PostinoSize.controlMd,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm))),
        child: kind == _Kind.image
            ? PostinoIcon(PostinoIcons.image, color: fg)
            : Text(
                label.length > 4 ? label.substring(0, 4) : label,
                maxLines: 1,
                // Inside its fixed 40 square: it does not grow with the text size.
                textScaler: TextScaler.noScaling,
                style: PostinoText.overline.copyWith(
                  color: fg,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }
}

enum _Kind() {
  pdf,
  doc,
  sheet,
  image,
  other,
}
