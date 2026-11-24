import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'litehtml_content.dart';
import 'litehtml_document.dart';
import 'litehtml_exception.dart';
import 'selection_layer.dart';
import 'semantics_layer.dart';

/// Rende [html] con litehtml alla larghezza [width]; l'altezza è quella del contenuto.
///
/// Layout sincrono sull'isolate UI a ogni cambio di html o larghezza (ADR 0025). Se il motore rifiuta l'HTML (non
/// fidato) la vista mostra [errorBuilder], dove il chiamante mette il ripiego.
///
/// Il testo è selezionabile dentro una `SelectionArea` antenata; titoli, paragrafi, link e immagini con `alt` sono
/// nodi Semantics in ordine di documento; Tab raggiunge i link e Invio li attiva.
class const LitehtmlView({
  super.key,
  required final String html,
  required final double width,
  required final Widget Function(BuildContext context, LitehtmlException error) errorBuilder,

  /// Chiamata con l'`href` quando un link è attivato da lettore di schermo o tastiera.
  final ValueChanged<String>? onLinkTap,

  /// Colore dell'anello di focus dei link: l'app passa il token del design system.
  final Color focusColor = const Color(0xFF0B57D0),
}) extends StatefulWidget {
  @override
  State<LitehtmlView> createState() => _LitehtmlViewState();
}

class _LitehtmlViewState() extends State<LitehtmlView> {
  LitehtmlDocument? _doc;
  ui.Picture? _picture;
  double _height = 0;
  LitehtmlContent _content = LitehtmlContent.empty;
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
      _content = _doc!.content();
      _error = null;
    } on LitehtmlException catch (e) {
      // Dopo un layout fallito il documento non serve più.
      _doc?.dispose();
      _doc = null;
      _content = LitehtmlContent.empty;
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _PicturePainter(_picture!)),
          LitehtmlSelectionLayer(content: _content),
          LitehtmlSemanticsLayer(content: _content, onLinkTap: widget.onLinkTap, focusColor: widget.focusColor),
        ],
      ),
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
