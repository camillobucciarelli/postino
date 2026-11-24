/// Binding FFI scritti a mano per `src/litehtml_c.h` (asset nativo da `hook/build.dart`).
// Le struct FFI non possono avere costruttori.
// ignore_for_file: use_primary_constructors
@DefaultAsset('package:litehtml_flutter/src/bindings.dart')
library;

import 'dart:ffi';

final class LhRect extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double w;
  @Float()
  external double h;
}

final class LhBorder extends Struct {
  @Float()
  external double width;
  @Int32()
  external int style;
  @Uint32()
  external int color;
}

final class LhBorders extends Struct {
  external LhRect box;
  external LhBorder left;
  external LhBorder top;
  external LhBorder right;
  external LhBorder bottom;
  @Array(8)
  external Array<Float> radii;
}

final class LhFontMetrics extends Struct {
  @Float()
  external double height;
  @Float()
  external double ascent;
  @Float()
  external double descent;
  @Float()
  external double xHeight;
  @Float()
  external double chWidth;
}

typedef CreateFontFn = Int64 Function(
  Pointer<Char> family,
  Float size,
  Int32 weight,
  Int32 italic,
  Int32 decoration,
  Pointer<LhFontMetrics> out,
);
typedef TextWidthFn = Float Function(Pointer<Char> text, Int64 font);
typedef DrawTextFn = Void Function(Pointer<Char> text, Int64 font, Uint32 color, Pointer<LhRect> pos);
typedef FillRectFn = Void Function(Pointer<LhRect> rect, Pointer<LhRect> clip, Pointer<Float> radii, Uint32 color);
typedef DrawBordersFn = Void Function(Pointer<LhBorders> borders);
typedef DrawImageFn = Void Function(Pointer<LhRect> rect, Pointer<Float> radii);
typedef SetClipFn = Void Function(Pointer<LhRect> rect, Pointer<Float> radii);
typedef DelClipFn = Void Function();

final class LhCallbacks extends Struct {
  external Pointer<NativeFunction<CreateFontFn>> createFont;
  external Pointer<NativeFunction<TextWidthFn>> textWidth;
  external Pointer<NativeFunction<DrawTextFn>> drawText;
  external Pointer<NativeFunction<FillRectFn>> fillRect;
  external Pointer<NativeFunction<DrawBordersFn>> drawBorders;
  external Pointer<NativeFunction<DrawImageFn>> drawImage;
  external Pointer<NativeFunction<SetClipFn>> setClip;
  external Pointer<NativeFunction<DelClipFn>> delClip;
}

final class LhDoc extends Opaque {}

/// Byte massimi dell'HTML accettato da [lhCreate] (`LH_MAX_HTML_BYTES`).
const lhMaxHtmlBytes = 4 * 1024 * 1024;

/// Esiti di [lhCreate] (`LH_OK`, `LH_TOO_LARGE`, `LH_FAILED`, `LH_TOO_DEEP`).
const lhOk = 0;
const lhTooLarge = 1;
const lhFailed = 2;
const lhTooDeep = 3;

@Native<Pointer<LhDoc> Function(Pointer<Char>, Size, Float, Pointer<LhCallbacks>, Pointer<Int32>)>(symbol: 'lh_create')
external Pointer<LhDoc> lhCreate(
  Pointer<Char> html,
  int length,
  double width,
  Pointer<LhCallbacks> cb,
  Pointer<Int32> status,
);

@Native<Float Function(Pointer<LhDoc>, Float)>(symbol: 'lh_render')
external double lhRender(Pointer<LhDoc> doc, double width);

@Native<Void Function(Pointer<LhDoc>)>(symbol: 'lh_draw')
external void lhDraw(Pointer<LhDoc> doc);

@Native<Void Function(Pointer<LhDoc>)>(symbol: 'lh_destroy')
external void lhDestroy(Pointer<LhDoc> doc);
