// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../tokens/postino_theme.dart';

/// A QR code of [data] for another device's camera (the Abbinamento, ADR 0019). Dark modules on a light ground in both
/// themes, the way every camera reads them: `ink` on `surface` in the light theme, the two swapped in the dark one;
/// around it the quiet zone of four modules the standard asks. One image for the screen reader, named by
/// [semanticLabel]: the modules are never read.
class const PostinoQrCode({
  super.key,

  /// Il testo codificato.
  required final String data,

  /// Il nome dell'immagine per lo screen reader.
  required final String semanticLabel,

  /// Lato in pixel logici, zona di rispetto compresa.
  final double size = 240,
}) extends StatelessWidget {
  /// Crea il QR.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final light = Theme.of(context).brightness == Brightness.light;
    final image = QrImage(QrCode(payload: QrPayload.fromString(data)));
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _QrPainter(image, dark: light ? c.ink : c.surface, ground: light ? c.surface : c.ink),
        ),
      ),
    );
  }
}

class const _QrPainter(final QrImage _image, {required final Color dark, required final Color ground})
    extends CustomPainter {
  static const _quiet = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final n = _image.moduleCount;
    final module = size.width / (n + 2 * _quiet);
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final ink = Paint()..color = dark;
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        if (_image.isDark(row, col)) {
          // A hair wider, so neighbouring modules leave no seam at fractional sizes.
          canvas.drawRect(
            Rect.fromLTWH((col + _quiet) * module, (row + _quiet) * module, module + 0.5, module + 0.5),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old._image != _image || old.dark != dark || old.ground != ground;
}
