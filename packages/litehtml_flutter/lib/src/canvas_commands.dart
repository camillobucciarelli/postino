import 'dart:ffi';
import 'dart:ui' as ui;

import 'bindings.dart';
import 'font_set.dart';

/// Esegue sul `Canvas` corrente i comandi di disegno emessi da litehtml.
class CanvasCommands(final FontSet _fonts) {
  ui.Canvas? canvas;

  /// Immagini caricate per `src`; quelle che mancano sono rettangoli grigi.
  final images = <String, ui.Image>{};

  static const _imageGrey = ui.Color(0xFFD0D0D0);

  void drawText(String text, int font, int color, LhRect pos) {
    final (paragraph, baseline) = _fonts.paragraph(text, font, ui.Color(color));
    final y = pos.y + pos.h - _fonts.descent(font) - baseline;
    canvas!.drawParagraph(paragraph, ui.Offset(pos.x, y));
  }

  void fillRect(LhRect rect, LhRect clip, Pointer<Float> radii, int color) {
    final c = canvas!;
    final r = _rect(rect);
    final clipRect = _rect(clip);
    final paint = ui.Paint()..color = ui.Color(color);
    final needsClip = !_contains(clipRect, r);
    if (needsClip) {
      c
        ..save()
        ..clipRect(clipRect);
    }
    if (_isZero(radii)) {
      c.drawRect(r, paint);
    } else {
      c.drawRRect(_rrect(r, radii), paint);
    }
    if (needsClip) c.restore();
  }

  // ponytail: l'immagine riempie il riquadro (niente object-fit).
  void drawImage(String src, LhRect rect, Pointer<Float> radii) {
    final c = canvas!;
    final r = _rect(rect);
    final image = images[src];
    if (image == null) {
      final paint = ui.Paint()..color = _imageGrey;
      _isZero(radii) ? c.drawRect(r, paint) : c.drawRRect(_rrect(r, radii), paint);
      return;
    }
    final round = !_isZero(radii);
    if (round) {
      c
        ..save()
        ..clipRRect(_rrect(r, radii));
    }
    c.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      r,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    if (round) c.restore();
  }

  /// Bordi per lato; con raggi e quattro lati uguali un anello arrotondato.
  // ponytail: dotted/dashed/double disegnati pieni; lati diversi con raggi senza curve.
  void drawBorders(LhBorders b) {
    final c = canvas!;
    final box = _rect(b.box);
    final sides = [b.left, b.top, b.right, b.bottom];
    bool visible(LhBorder s) => s.width > 0 && s.style > 1; // 0 none, 1 hidden
    if (!sides.any(visible)) return;
    final uniform = sides.every((s) => visible(s) && s.width == b.left.width && s.color == b.left.color);
    final hasRadius = List.generate(8, (i) => b.radii[i]).any((v) => v > 0);
    if (uniform && hasRadius) {
      final outer = ui.RRect.fromRectAndCorners(
        box,
        topLeft: ui.Radius.elliptical(b.radii[0], b.radii[1]),
        topRight: ui.Radius.elliptical(b.radii[2], b.radii[3]),
        bottomRight: ui.Radius.elliptical(b.radii[4], b.radii[5]),
        bottomLeft: ui.Radius.elliptical(b.radii[6], b.radii[7]),
      );
      c.drawDRRect(outer, outer.deflate(b.left.width), ui.Paint()..color = ui.Color(b.left.color));
      return;
    }
    void side(LhBorder s, ui.Rect r) {
      if (visible(s)) c.drawRect(r, ui.Paint()..color = ui.Color(s.color));
    }

    side(b.top, ui.Rect.fromLTWH(box.left, box.top, box.width, b.top.width));
    side(b.bottom, ui.Rect.fromLTWH(box.left, box.bottom - b.bottom.width, box.width, b.bottom.width));
    side(b.left, ui.Rect.fromLTWH(box.left, box.top, b.left.width, box.height));
    side(b.right, ui.Rect.fromLTWH(box.right - b.right.width, box.top, b.right.width, box.height));
  }

  void setClip(LhRect rect, Pointer<Float> radii) {
    final c = canvas!..save();
    final r = _rect(rect);
    _isZero(radii) ? c.clipRect(r) : c.clipRRect(_rrect(r, radii));
  }

  void delClip() => canvas!.restore();

  static ui.Rect _rect(LhRect r) => ui.Rect.fromLTWH(r.x, r.y, r.w, r.h);

  static bool _contains(ui.Rect outer, ui.Rect inner) =>
      outer.left <= inner.left && outer.top <= inner.top && outer.right >= inner.right && outer.bottom >= inner.bottom;

  static bool _isZero(Pointer<Float> radii) {
    for (var i = 0; i < 8; i++) {
      if (radii[i] != 0) return false;
    }
    return true;
  }

  static ui.RRect _rrect(ui.Rect r, Pointer<Float> radii) => ui.RRect.fromRectAndCorners(
    r,
    topLeft: ui.Radius.elliptical(radii[0], radii[1]),
    topRight: ui.Radius.elliptical(radii[2], radii[3]),
    bottomRight: ui.Radius.elliptical(radii[4], radii[5]),
    bottomLeft: ui.Radius.elliptical(radii[6], radii[7]),
  );
}
