import 'dart:ffi';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'canvas_commands.dart';
import 'font_set.dart';

/// Un documento litehtml vivo: DOM nativo, font e callback sono suoi (nessuno stato globale).
///
/// Le callback sono `NativeCallable.isolateLocal`: vanno usate solo dall'isolate che ha creato il documento.
class LitehtmlDocument {
  LitehtmlDocument(String html, double width) : _width = width {
    _commands = CanvasCommands(_fonts);
    _callbacks = calloc<LhCallbacks>();
    _callbacks.ref
      ..createFont = _own(NativeCallable<CreateFontFn>.isolateLocal(_createFont, exceptionalReturn: 0)).nativeFunction
      ..textWidth = _own(NativeCallable<TextWidthFn>.isolateLocal(_textWidth, exceptionalReturn: 0.0)).nativeFunction
      ..drawText = _own(NativeCallable<DrawTextFn>.isolateLocal(_drawText)).nativeFunction
      ..fillRect = _own(NativeCallable<FillRectFn>.isolateLocal(_fillRect)).nativeFunction
      ..drawBorders = _own(NativeCallable<DrawBordersFn>.isolateLocal(_drawBorders)).nativeFunction
      ..drawImage = _own(NativeCallable<DrawImageFn>.isolateLocal(_drawImage)).nativeFunction
      ..setClip = _own(NativeCallable<SetClipFn>.isolateLocal(_setClip)).nativeFunction
      ..delClip = _own(NativeCallable<DelClipFn>.isolateLocal(_delClip)).nativeFunction;
    final source = html.toNativeUtf8();
    try {
      _doc = lhCreate(source.cast(), width, _callbacks);
    } finally {
      calloc.free(source);
    }
    if (_doc == nullptr) {
      dispose();
      throw StateError('litehtml non ha creato il documento');
    }
  }

  final _fonts = FontSet();
  late final CanvasCommands _commands;
  late final Pointer<LhCallbacks> _callbacks;
  final _callables = <NativeCallable<Function>>[];
  Pointer<LhDoc> _doc = nullptr;
  double _width;

  /// Chiamate C++→Dart per nome di callback, dalla creazione del documento.
  final calls = <String, int>{};

  /// Tempo passato dentro la callback Dart `text_width` (la più chiamata), in µs.
  int textWidthUs = 0;

  /// Stringhe misurate davvero con un `Paragraph` (le altre escono dalla cache per font).
  int get measuredStrings => _fonts.measured;

  double get width => _width;

  /// Layout alla larghezza data; restituisce l'altezza del contenuto.
  double layout(double width) {
    _width = width;
    final height = lhRender(_doc, width);
    if (height < 0) throw StateError('layout litehtml fallito');
    return height;
  }

  /// Registra i comandi di disegno dell'ultimo layout in una `Picture`.
  ui.Picture record() {
    final recorder = ui.PictureRecorder();
    _commands.canvas = ui.Canvas(recorder);
    try {
      lhDraw(_doc);
    } finally {
      _commands.canvas = null;
    }
    return recorder.endRecording();
  }

  void dispose() {
    if (_doc != nullptr) lhDestroy(_doc);
    _doc = nullptr;
    for (final c in _callables) {
      c.close();
    }
    _callables.clear();
    calloc.free(_callbacks);
  }

  NativeCallable<T> _own<T extends Function>(NativeCallable<T> callable) {
    _callables.add(callable);
    return callable;
  }

  void _count(String name) => calls[name] = (calls[name] ?? 0) + 1;

  int _createFont(
    Pointer<Char> family,
    double size,
    int weight,
    int italic,
    int decoration,
    Pointer<LhFontMetrics> out,
  ) {
    _count('create_font');
    final (id, m) = _fonts.create(family.cast<Utf8>().toDartString(), size, weight, italic != 0, decoration);
    out.ref
      ..height = m.height
      ..ascent = m.ascent
      ..descent = m.descent
      ..xHeight = m.xHeight
      ..chWidth = m.chWidth;
    return id;
  }

  double _textWidth(Pointer<Char> text, int font) {
    _count('text_width');
    final sw = Stopwatch()..start();
    final width = _fonts.width(text.cast<Utf8>().toDartString(), font);
    textWidthUs += sw.elapsedMicroseconds;
    return width;
  }

  void _drawText(Pointer<Char> text, int font, int color, Pointer<LhRect> pos) {
    _count('draw_text');
    _commands.drawText(text.cast<Utf8>().toDartString(), font, color, pos.ref);
  }

  void _fillRect(Pointer<LhRect> rect, Pointer<LhRect> clip, Pointer<Float> radii, int color) {
    _count('fill_rect');
    _commands.fillRect(rect.ref, clip.ref, radii, color);
  }

  void _drawBorders(Pointer<LhBorders> borders) {
    _count('draw_borders');
    _commands.drawBorders(borders.ref);
  }

  void _drawImage(Pointer<LhRect> rect, Pointer<Float> radii) {
    _count('draw_image');
    _commands.drawImage(rect.ref, radii);
  }

  void _setClip(Pointer<LhRect> rect, Pointer<Float> radii) {
    _count('set_clip');
    _commands.setClip(rect.ref, radii);
  }

  void _delClip() {
    _count('del_clip');
    _commands.delClip();
  }
}
