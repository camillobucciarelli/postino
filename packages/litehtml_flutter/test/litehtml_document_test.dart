import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

/// Pixel ARGB del documento disegnato a [width] x [height], riga per riga.
Future<List<int>> pixels(LitehtmlDocument doc, int width, int height) async {
  final picture = doc.record();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final bytes = (await image.toByteData())!;
  image.dispose();
  return [
    for (var i = 0; i < width * height * 4; i += 4)
      bytes.getUint8(i + 3) << 24 | bytes.getUint8(i) << 16 | bytes.getUint8(i + 1) << 8 | bytes.getUint8(i + 2),
  ];
}

void main() {
  test('sfondi, bordi, immagini e testo arrivano sul Canvas', () async {
    const html =
        '<body style="margin: 0"> '
        '<div style="background: #ff0000; width: 20px; height: 20px"></div> '
        '<div style="border: 4px solid #0000ff; width: 20px; height: 20px"></div> '
        '<img src="x.png" width="20" height="20"> '
        '<p style="margin: 0; font-size: 40px; color: #00ff00">MM</p>';
    final doc = LitehtmlDocument(html, 100);
    addTearDown(doc.dispose);
    final height = doc.layout(100).ceil();
    final image = await pixels(doc, 100, height);
    int at(int x, int y) => image[y * 100 + x];

    expect(height, greaterThan(68));
    expect(at(10, 10), 0xFFFF0000);
    expect(at(1, 30), 0xFF0000FF);
    // Le immagini non si caricano: rettangolo grigio della dimensione degli attributi.
    expect(at(10, 58), 0xFFD0D0D0);
    expect(image.skip(100 * 70), contains(0xFF00FF00), reason: 'testo verde sotto l\'immagine');
  });

  test('una larghezza minore allunga il documento', () {
    final doc = LitehtmlDocument('<p>${'parola ' * 200}</p>', 600);
    addTearDown(doc.dispose);

    expect(doc.layout(300), greaterThan(doc.layout(600)));
  });

  test('le media query seguono la larghezza del relayout', () {
    const html =
        '<body style="margin: 0"><style>@media (max-width: 500px) { .wide { display: none; } }</style> '
        '<div class="wide" style="height: 100px"></div><div style="height: 10px"></div>';
    final doc = LitehtmlDocument(html, 600);
    addTearDown(doc.dispose);

    expect(doc.layout(600), 110);
    expect(doc.layout(400), 10);
  });

  test('td height=40 spaziatore dà una riga di 40 px (patch postino)', () {
    const html =
        '<body style="margin: 0"><table width="100%" style="max-width: 300px" cellpadding="0" cellspacing="0"> '
        '<tr><td height="40" style="font-size: 0; line-height: 0">&nbsp;</td></tr></table>';
    final doc = LitehtmlDocument(html, 600);
    addTearDown(doc.dispose);

    expect(doc.layout(600), 40);
  });

  test('larghezza non finita o non positiva rifiutata', () {
    expect(() => LitehtmlDocument('<p>x</p>', 0), throwsArgumentError);
    final doc = LitehtmlDocument('<p>x</p>', 100);
    addTearDown(doc.dispose);
    expect(() => doc.layout(double.infinity), throwsArgumentError);
    expect(() => doc.layout(double.nan), throwsArgumentError);
  });

  test('un documento liberato non si usa più e dispose è idempotente', () {
    final doc = LitehtmlDocument('<p>x</p>', 100)..dispose();

    expect(() => doc.layout(100), throwsStateError);
    expect(doc.record, throwsStateError);
    doc.dispose();
  });

  test('il record senza layout non va in crash', () {
    final doc = LitehtmlDocument('<p>x</p>', 100);
    addTearDown(doc.dispose);

    expect(doc.record(), isA<ui.Picture>());
  });
}
