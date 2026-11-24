import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'litehtml_content.dart';
import 'litehtml_document.dart';
import 'litehtml_exception.dart';
import 'litehtml_images.dart';
import 'litehtml_link_detector.dart';
import 'litehtml_picture_cache.dart';
import 'selection_layer.dart';
import 'semantics_layer.dart';

/// Rende [html] con litehtml alla larghezza [width]; l'altezza è quella del contenuto.
///
/// Layout sincrono sull'isolate UI (ADR 0025): un nuovo html crea un nuovo documento, una nuova larghezza rifà solo il
/// layout dello stesso DOM. Se il motore rifiuta l'HTML (non fidato) la vista mostra [errorBuilder], dove il chiamante
/// mette il ripiego.
///
/// Gli `<img>` si caricano con [imageProvider] e, arrivati, si ridisegnano (con un nuovo layout se cambiano le
/// dimensioni). Uscendo dall'albero la vista libera il DOM e lascia `Picture` e contenuto in
/// [LitehtmlPictureCache.shared].
///
/// Il testo è selezionabile dentro una `SelectionArea` antenata; titoli, paragrafi, link e immagini con `alt` sono
/// nodi Semantics in ordine di documento; Tab raggiunge i link e Invio li attiva.
class const LitehtmlView({
  super.key,
  required final String html,
  required final double width,
  required final Widget Function(BuildContext context, LitehtmlException error) errorBuilder,

  /// Chiamata con l'`href` (grezzo) di un link toccato o attivato da tastiera e lettore di schermo; null: nessun link
  /// attivo.
  final ValueChanged<String>? onLinkTap,

  /// Nome per i lettori di schermo di un `<img>` senza `src` (immagine bloccata), prima del suo `alt`.
  final String? blockedImageLabel,

  /// Colore dell'anello di focus dei link: l'app passa il token del design system.
  final Color focusColor = const Color(0xFF0B57D0),

  /// Da `src` a immagine; null per non caricarla.
  final ImageProvider? Function(String src) imageProvider = litehtmlImageProvider,
}) extends StatefulWidget {
  @override
  State<LitehtmlView> createState() => _LitehtmlViewState();
}

class _LitehtmlViewState() extends State<LitehtmlView> {
  static final _cache = LitehtmlPictureCache.shared;

  /// Null anche quando la `Picture` viene dalla cache: il DOM si ricrea al primo bisogno.
  LitehtmlDocument? _doc;
  LitehtmlImages? _images;

  /// Larghezza dell'ultimo layout di [_doc].
  double? _laidOut;
  ui.Picture? _picture;
  double _height = 0;
  LitehtmlContent _content = LitehtmlContent.empty;
  LitehtmlException? _error;

  /// Un'immagine è arrivata dopo l'ultima `Picture` ([_relayout]: e ne cambia le dimensioni).
  var _stale = false;
  var _relayout = false;

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void didUpdateWidget(LitehtmlView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      _stash(old);
      _disposeDoc();
      _show();
    } else if (old.width != widget.width && _error == null) {
      // Le larghezze intermedie di un ridimensionamento non vanno in cache: la svuoterebbero.
      _picture?.dispose();
      _picture = null;
      _show();
    }
  }

  /// La `Picture` di html e larghezza correnti: dalla cache se c'è, altrimenti layout e disegno.
  void _show() {
    _error = null;
    if (_cache.take(widget.html, widget.width) case (final picture, final height, final content)) {
      _picture = picture;
      _height = height;
      _content = content;
      return;
    }
    _render();
  }

  void _render() {
    try {
      final doc = _layout();
      _stale = false;
      final old = _picture;
      _picture = doc.record();
      old?.dispose();
      _content = doc.content(blockedImageLabel: widget.blockedImageLabel);
    } on LitehtmlException catch (e) {
      // Dopo un layout fallito il documento non serve più.
      _disposeDoc();
      _picture?.dispose();
      _picture = null;
      _content = LitehtmlContent.empty;
      _error = e;
    }
  }

  /// Il documento, creato se manca, impaginato alla larghezza corrente.
  LitehtmlDocument _layout() {
    final doc = _doc ??= _create();
    if (_laidOut != widget.width || _relayout) {
      _relayout = false;
      _height = doc.layout(widget.width);
      _laidOut = widget.width;
    }
    return doc;
  }

  LitehtmlDocument _create() {
    final doc = LitehtmlDocument(widget.html, widget.width);
    _laidOut = null;
    _images = LitehtmlImages(widget.imageProvider, (src, info) {
      if (_doc != null && _doc != doc) return;
      if (doc.setImage(src, info.image, scale: info.scale)) _relayout = true;
      if (_stale) return;
      _stale = true;
      // Le immagini arrivate nello stesso evento diventano una sola nuova `Picture`.
      scheduleMicrotask(() {
        if (mounted && _stale && _doc == doc) setState(_render);
      });
    })..load(doc.imageSources);
    return doc;
  }

  /// `href` sotto [p], dai box dei link conservati con la `Picture`: testo e immagini di un link, l'area intera di
  /// un'ancora a blocco o inline-block. Validi anche senza DOM (documento dalla cache).
  String? _linkAt(Offset p) {
    if (_error != null) return null;
    for (final link in _content.links) {
      if (link.rects.any((r) => r.contains(p))) return link.href;
    }
    return null;
  }

  /// La `Picture` completa (nessuna immagine in arrivo o fallita: riaprendo si riprova) va in cache, le altre si
  /// liberano.
  void _stash(LitehtmlView of) {
    final picture = _picture;
    _picture = null;
    if (picture == null) return;
    if ((_images?.complete ?? true) && !_stale) {
      _cache.put(of.html, of.width, picture, _height, _content);
    } else {
      picture.dispose();
    }
  }

  void _disposeDoc() {
    _images?.dispose();
    _images = null;
    _doc?.dispose();
    _doc = null;
    _laidOut = null;
    _stale = _relayout = false;
  }

  @override
  void dispose() {
    _stash(widget);
    _disposeDoc();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return widget.errorBuilder(context, error);
    final view = SizedBox(
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
    final onLinkTap = widget.onLinkTap;
    return onLinkTap == null ? view : LitehtmlLinkDetector(linkAt: _linkAt, onTap: onLinkTap, child: view);
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
