import 'dart:ui' as ui;

import 'font_metrics.dart';

/// Font di un documento: litehtml li chiede con `create_font` e li cita per id.
///
/// La misura usa `ui.Paragraph`, lo stesso motore del testo dell'app.
class FontSet() {
  final _fonts = <_Font>[];

  /// Crea un font e restituisce `(id, metriche)`; l'id parte da 1 (0 per litehtml è "nessun font").
  (int, FontMetrics) create(String family, double size, int weight, bool italic, int decoration) {
    final families = family.split(',').map(_resolve).where((f) => f.isNotEmpty).toList();
    final style = ui.TextStyle(
      fontFamily: families.isEmpty ? null : families.first,
      fontFamilyFallback: families.length > 1 ? families.sublist(1) : null,
      fontSize: size,
      fontWeight: ui.FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
      fontStyle: italic ? ui.FontStyle.italic : ui.FontStyle.normal,
      decoration: ui.TextDecoration.combine([
        if (decoration & 1 != 0) ui.TextDecoration.underline,
        if (decoration & 2 != 0) ui.TextDecoration.overline,
        if (decoration & 4 != 0) ui.TextDecoration.lineThrough,
      ]),
    );
    final font = _Font(style);
    final zero = font.paragraph('0');
    final line = zero.computeLineMetrics().first;
    final metrics = FontMetrics(
      ascent: line.ascent,
      descent: line.descent,
      height: line.ascent + line.descent,
      // ponytail: x-height stimata (0,52 em); misurarla serve un glifo dal font.
      xHeight: size * 0.52,
      chWidth: zero.maxIntrinsicWidth,
    );
    font.descent = line.descent;
    _fonts.add(font);
    return (_fonts.length, metrics);
  }

  /// Larghezza di [text] nel font [id], con una cache per font (litehtml misura spesso le stesse parole).
  double width(String text, int id) {
    final font = _fonts[id - 1];
    return font.widths[text] ??= font.paragraph(text).maxIntrinsicWidth;
  }

  /// Paragrafo pronto da dipingere e distanza dal suo top alla baseline.
  (ui.Paragraph, double) paragraph(String text, int id, ui.Color color) {
    final font = _fonts[id - 1];
    final p = font.paragraph(text, color: color);
    return (p, p.alphabeticBaseline);
  }

  double descent(int id) => _fonts[id - 1].descent;

  /// Famiglie generiche e di sistema mappate sui nomi dei font di macOS.
  static String _resolve(String raw) {
    final name = raw.trim().replaceAll('"', '').replaceAll("'", '');
    return switch (name.toLowerCase()) {
      'sans-serif' => 'Helvetica',
      'serif' => 'Times New Roman',
      'monospace' => 'Courier New',
      'system-ui' || '-apple-system' || 'blinkmacsystemfont' => '.AppleSystemUIFont',
      _ => name,
    };
  }
}

class _Font(final ui.TextStyle style) {
  final widths = <String, double>{};
  double descent = 0;

  ui.Paragraph paragraph(String text, {ui.Color? color}) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))..pushStyle(style);
    if (color != null) builder.pushStyle(ui.TextStyle(color: color, decorationColor: color));
    builder.addText(text);
    return builder.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
  }
}
