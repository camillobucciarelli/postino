import 'dart:io';
import 'dart:ui' as ui;

import 'package:litehtml_flutter/litehtml_flutter.dart';

/// Tempi di un giro: creazione (parse + stili), layout, draw (registrazione della `Picture`).
typedef Timing = ({int createUs, int layoutUs, int drawUs, int textWidthUs});

class BenchResult {
  BenchResult(this.name, this.width, this.height, this.runs, this.calls, this.measuredStrings);

  final String name;
  final double width;
  final double height;
  final List<Timing> runs;

  /// Callback per fase (`create`, `layout`, `draw`) e per nome.
  final Map<String, Map<String, int>> calls;

  /// Stringhe misurate davvero con un `Paragraph` per giro (il resto di `text_width` viene dalla cache).
  final int measuredStrings;
}

/// Rende [html] [runs] volte alla larghezza data, ognuna con un documento nuovo; salva il PNG dell'ultima.
Future<BenchResult> bench(String name, String html, double width, int runs, String pngPath) async {
  final timings = <Timing>[];
  late Map<String, Map<String, int>> calls;
  late double height;
  var measured = 0;
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    final doc = LitehtmlDocument(html, width);
    final createUs = sw.elapsedMicroseconds;
    final afterCreate = Map.of(doc.calls);
    height = doc.layout(width);
    final layoutUs = sw.elapsedMicroseconds - createUs;
    final afterLayout = Map.of(doc.calls);
    final picture = doc.record();
    final drawUs = sw.elapsedMicroseconds - createUs - layoutUs;
    timings.add((createUs: createUs, layoutUs: layoutUs, drawUs: drawUs, textWidthUs: doc.textWidthUs));
    measured = doc.measuredStrings;
    calls = {'create': afterCreate, 'layout': _diff(afterLayout, afterCreate), 'draw': _diff(doc.calls, afterLayout)};
    doc.dispose();
    if (i == runs - 1) await _writePng(picture, width, height, pngPath);
    picture.dispose();
  }
  return BenchResult(name, width, height, timings, calls, measured);
}

Map<String, int> _diff(Map<String, int> after, Map<String, int> before) => {
  for (final e in after.entries)
    if (e.value - (before[e.key] ?? 0) > 0) e.key: e.value - (before[e.key] ?? 0),
};

/// PNG a 2x su fondo bianco, come lo screenshot del browser.
Future<void> _writePng(ui.Picture picture, double width, double height, String path) async {
  const scale = 2.0;
  final recorder = ui.PictureRecorder();
  final size = ui.Size(width, height.ceilToDouble());
  ui.Canvas(recorder)
    ..scale(scale)
    ..drawRect(ui.Offset.zero & size, ui.Paint()..color = const ui.Color(0xFFFFFFFF))
    ..drawPicture(picture);
  final scaled = recorder.endRecording();
  final image = await scaled.toImage((size.width * scale).round(), (size.height * scale).round());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  scaled.dispose();
  await File(path).writeAsBytes(png!.buffer.asUint8List());
}
