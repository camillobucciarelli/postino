import 'dart:ffi';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'canvas_commands.dart';
import 'font_set.dart';
import 'litehtml_exception.dart';

/// Un documento litehtml vivo: DOM nativo, font e callback sono suoi (nessuno stato globale).
///
/// L'HTML non è fidato: il motore rifiuta documenti troppo grandi o annidati e interrompe layout troppo costosi
/// con una [LitehtmlException] (limiti in `third_party/litehtml/VERSION`).
///
/// Le callback sono `NativeCallable.isolateLocal` e il layout gira sincrono sul thread dell'isolate che ha creato il
/// documento (ADR 0025): va usato solo da quell'isolate.
///
/// Il costruttore analizza `html` e applica gli stili per una viewport larga `width`; lancia [LitehtmlException] se
/// il motore rifiuta l'HTML.
class LitehtmlDocument(String html, double width) {
  this {
    _checkWidth(width);
    // Le unità UTF-16 non superano i byte UTF-8: oltre il limite si evita anche di copiare la stringa.
    if (html.length > lhMaxHtmlBytes) throw const LitehtmlException(LitehtmlFailure.tooLarge);
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
      ..delClip = _own(NativeCallable<DelClipFn>.isolateLocal(_delClip)).nativeFunction
      ..loadImage = _own(NativeCallable<LoadImageFn>.isolateLocal(_loadImage)).nativeFunction;
    final source = html.toNativeUtf8(allocator: calloc);
    final status = calloc<Int32>();
    try {
      _doc = lhCreate(source.cast(), source.length, width, _callbacks, status);
      if (_doc == nullptr) {
        dispose();
        throw LitehtmlException(switch (status.value) {
          lhTooLarge => LitehtmlFailure.tooLarge,
          lhTooDeep => LitehtmlFailure.tooDeep,
          _ => LitehtmlFailure.failed,
        });
      }
    } finally {
      calloc
        ..free(source)
        ..free(status);
    }
  }

  final _fonts = FontSet();
  late final CanvasCommands _commands;
  late final Pointer<LhCallbacks> _callbacks;
  final _callables = <NativeCallable<Function>>[];
  Pointer<LhDoc> _doc = nullptr;
  final _sources = <String>[];

  /// I `src` non vuoti degli `<img>`, in ordine di documento e senza doppioni: il chiamante li carica e li passa a
  /// [setImage]. Finché un'immagine manca, al suo posto c'è un rettangolo grigio.
  List<String> get imageSources => List.unmodifiable(_sources);

  /// Immagine caricata per [src], disegnata dal prossimo [record]. Restituisce true se la sua dimensione naturale
  /// cambia il layout: allora serve un nuovo [layout] prima di [record].
  bool setImage(String src, ui.Image image, {double scale = 1}) {
    _commands.images[src] = image;
    final native = src.toNativeUtf8(allocator: calloc);
    try {
      return lhSetImageSize(_live, native.cast(), image.width / scale, image.height / scale) != 0;
    } finally {
      calloc.free(native);
    }
  }

  /// `href` del link sotto [x], [y] (coordinate dell'ultimo layout), o null.
  String? linkAt(double x, double y) {
    final href = lhLinkAt(_live, x, y);
    return href == nullptr ? null : href.cast<Utf8>().toDartString();
  }

  /// Layout alla larghezza data; restituisce l'altezza del contenuto.
  ///
  /// Lancia [LitehtmlException] se il layout fallisce: il documento non è più utilizzabile.
  double layout(double width) {
    _checkWidth(width);
    final height = lhRender(_live, width);
    if (height < 0) throw const LitehtmlException(LitehtmlFailure.layout);
    return height;
  }

  /// Registra i comandi di disegno dell'ultimo layout in una `Picture`.
  ui.Picture record() {
    final recorder = ui.PictureRecorder();
    _commands.canvas = ui.Canvas(recorder);
    try {
      lhDraw(_live);
    } finally {
      _commands.canvas = null;
    }
    return recorder.endRecording();
  }

  /// Libera DOM nativo e callback; il documento non è più utilizzabile. Idempotente.
  void dispose() {
    _commands.images.clear();
    if (_doc != nullptr) lhDestroy(_doc);
    _doc = nullptr;
    if (_callables.isEmpty) return;
    for (final c in _callables) {
      c.close();
    }
    _callables.clear();
    calloc.free(_callbacks);
  }

  Pointer<LhDoc> get _live => _doc == nullptr ? throw StateError('LitehtmlDocument già liberato') : _doc;

  static void _checkWidth(double width) {
    if (!(width > 0 && width.isFinite)) throw ArgumentError.value(width, 'width', 'deve essere finita e positiva');
  }

  NativeCallable<T> _own<T extends Function>(NativeCallable<T> callable) {
    _callables.add(callable);
    return callable;
  }

  int _createFont(
    Pointer<Char> family,
    double size,
    int weight,
    int italic,
    int decoration,
    Pointer<LhFontMetrics> out,
  ) {
    final (id, m) = _fonts.create(family.cast<Utf8>().toDartString(), size, weight, italic != 0, decoration);
    out.ref
      ..height = m.height
      ..ascent = m.ascent
      ..descent = m.descent
      ..xHeight = m.xHeight
      ..chWidth = m.chWidth;
    return id;
  }

  double _textWidth(Pointer<Char> text, int font) => _fonts.width(text.cast<Utf8>().toDartString(), font);

  void _drawText(Pointer<Char> text, int font, int color, Pointer<LhRect> pos) =>
      _commands.drawText(text.cast<Utf8>().toDartString(), font, color, pos.ref);

  void _fillRect(Pointer<LhRect> rect, Pointer<LhRect> clip, Pointer<Float> radii, int color) =>
      _commands.fillRect(rect.ref, clip.ref, radii, color);

  void _drawBorders(Pointer<LhBorders> borders) => _commands.drawBorders(borders.ref);

  void _drawImage(Pointer<Char> src, Pointer<LhRect> rect, Pointer<Float> radii) =>
      _commands.drawImage(src.cast<Utf8>().toDartString(), rect.ref, radii);

  void _loadImage(Pointer<Char> src) => _sources.add(src.cast<Utf8>().toDartString());

  void _setClip(Pointer<LhRect> rect, Pointer<Float> radii) => _commands.setClip(rect.ref, radii);

  void _delClip() => _commands.delClip();
}
