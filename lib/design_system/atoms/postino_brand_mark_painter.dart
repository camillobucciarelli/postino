import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_palette.dart';

/// `assets/brand/mark.svg` (viewBox 256) at [progress] of the opening (#267): 0 the envelope closed, the letter
/// inside; up to 250/900 the flap rises (easeInOut); then the letter rises and turns to -5° (easeOutCubic);
/// 1 is mark.svg. Colors and shapes copied from the SVG: if it changes, change them here too.
class PostinoBrandMarkPainter(
  /// Da 0 (busta chiusa) a 1 (mark.svg); ridisegna a ogni suo cambio.
  final Animation<double> progress,
) extends CustomPainter {
  /// Crea il painter del marchio.
  this : super(repaint: progress);

  static const _flapEnd = 250 / 900;
  static const _paper = Color(0xFFFFFDF8);
  static const _gold = Color(0xFFE0AB12);

  /// The flap folded over the pocket (-1) up to open as in mark.svg (1).
  double get flapFold => 2 * Curves.easeInOut.transform(math.min(progress.value / _flapEnd, 1)) - 1;

  /// The letter inside the pocket (0) up to its place in mark.svg (1).
  double get letterRise =>
      Curves.easeOutCubic.transform(((progress.value - _flapEnd) / (1 - _flapEnd)).clamp(0, 1).toDouble());

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 256, size.height / 256);
    final fold = flapFold;
    // Hinged on y = 128: open it is behind the letter, folded it is in front of the pocket.
    final flap = Path()
      ..moveTo(40, 128)
      ..lineTo(128, 128 - 72 * fold)
      ..lineTo(216, 128)
      ..close();
    final flapPaint = Paint()..color = PostinoPrimitives.pNeutral200;
    if (fold >= 0) canvas.drawPath(flap, flapPaint);
    _letter(canvas, letterRise);
    canvas
      ..drawPath(_pocket(4), Paint()..color = const Color(0x38000000))
      ..drawPath(_pocket(0), Paint()..color = _paper);
    if (fold < 0) canvas.drawPath(flap, flapPaint);
    canvas.restore();
  }

  /// The letter, 56 lower and straight when inside, clipped at the pocket's bottom so it never shows below it.
  void _letter(Canvas canvas, double rise) {
    Paint line(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..clipRect(const Rect.fromLTRB(0, 0, 256, 204))
      ..translate(128, 128 + 56 * (1 - rise))
      ..rotate(-5 * math.pi / 180 * rise)
      ..translate(-128, -128)
      ..drawRRect(RRect.fromLTRBR(76, 76, 180, 188, const Radius.circular(10)), Paint()..color = _paper)
      ..drawLine(const Offset(128, 96), const Offset(164, 96), line(PostinoPrimitives.pNeutral300))
      ..drawLine(const Offset(92, 112), const Offset(168, 112), line(PostinoPrimitives.pNeutral300))
      ..drawLine(const Offset(92, 96), const Offset(120, 96), line(_gold))
      ..restore();
  }

  /// The pocket, [dy] lower for its flat shadow.
  static Path _pocket(double dy) => Path()
    ..moveTo(40, 128 + dy)
    ..lineTo(216, 128 + dy)
    ..lineTo(216, 190 + dy)
    ..quadraticBezierTo(216, 204 + dy, 202, 204 + dy)
    ..lineTo(54, 204 + dy)
    ..quadraticBezierTo(40, 204 + dy, 40, 190 + dy)
    ..close();

  @override
  bool shouldRepaint(PostinoBrandMarkPainter old) => old.progress != progress;
}
