import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'litehtml_document.dart';

/// Rende [html] con litehtml alla larghezza [width]; l'altezza è quella del contenuto.
///
/// Layout sincrono sull'isolate UI a ogni cambio di html o larghezza (ADR 0025). Un HTML rifiutato dal motore lancia
/// `LitehtmlException` da `initState`/`didUpdateWidget`: con HTML non fidato chi lo usa gestisce il ripiego.
class const LitehtmlView({super.key, required final String html, required final double width}) extends StatefulWidget {
  @override
  State<LitehtmlView> createState() => _LitehtmlViewState();
}

class _LitehtmlViewState() extends State<LitehtmlView> {
  LitehtmlDocument? _doc;
  ui.Picture? _picture;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    _render(newHtml: true);
  }

  @override
  void didUpdateWidget(LitehtmlView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html || old.width != widget.width) _render(newHtml: old.html != widget.html);
  }

  /// Nuovo html = nuovo documento; nuova larghezza = solo relayout dello stesso DOM.
  void _render({required bool newHtml}) {
    if (newHtml) {
      _release();
      _doc = LitehtmlDocument(widget.html, widget.width);
    }
    _picture?.dispose();
    _height = _doc!.layout(widget.width);
    _picture = _doc!.record();
  }

  void _release() {
    _picture?.dispose();
    _doc?.dispose();
    _picture = null;
    _doc = null;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: _height,
    child: CustomPaint(painter: _PicturePainter(_picture!)),
  );
}

class _PicturePainter(final ui.Picture picture) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..clipRect(Offset.zero & size)
      ..drawPicture(picture);
  }

  @override
  bool shouldRepaint(_PicturePainter old) => old.picture != picture;
}
