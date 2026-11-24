import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'litehtml_document.dart';
import 'litehtml_exception.dart';

/// Rende [html] con litehtml alla larghezza [width]; l'altezza è quella del contenuto.
///
/// Layout sincrono sull'isolate UI a ogni cambio di html o larghezza (ADR 0025). Se il motore rifiuta l'HTML (non
/// fidato) la vista mostra [errorBuilder], dove il chiamante mette il ripiego.
class const LitehtmlView({
  super.key,
  required final String html,
  required final double width,
  required final Widget Function(BuildContext context, LitehtmlException error) errorBuilder,
}) extends StatefulWidget {
  @override
  State<LitehtmlView> createState() => _LitehtmlViewState();
}

class _LitehtmlViewState() extends State<LitehtmlView> {
  LitehtmlDocument? _doc;
  ui.Picture? _picture;
  double _height = 0;
  LitehtmlException? _error;

  @override
  void initState() {
    super.initState();
    _render(newHtml: true);
  }

  @override
  void didUpdateWidget(LitehtmlView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      _render(newHtml: true);
    } else if (old.width != widget.width && _error == null) {
      _render(newHtml: false);
    }
  }

  /// Nuovo html = nuovo documento; nuova larghezza = solo relayout dello stesso DOM.
  void _render({required bool newHtml}) {
    _picture?.dispose();
    _picture = null;
    try {
      if (newHtml) {
        _doc?.dispose();
        _doc = null;
        _doc = LitehtmlDocument(widget.html, widget.width);
      }
      _height = _doc!.layout(widget.width);
      _picture = _doc!.record();
      _error = null;
    } on LitehtmlException catch (e) {
      // Dopo un layout fallito il documento non serve più.
      _doc?.dispose();
      _doc = null;
      _error = e;
    }
  }

  @override
  void dispose() {
    _picture?.dispose();
    _doc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return widget.errorBuilder(context, error);
    return SizedBox(
      width: widget.width,
      height: _height,
      child: CustomPaint(painter: _PicturePainter(_picture!)),
    );
  }
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
