import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'litehtml_content.dart';

/// Un link del contenuto per lettori di schermo e tastiera, grande quanto i suoi box.
///
/// Nodo Semantics con ruolo link e azione tap; fermata di Tab con l'anello di focus attorno a ogni riga del link (solo
/// quando il focus arriva dalla tastiera, come gli altri controlli); Invio lo attiva (ADR 0014).
class const LinkTarget({
  super.key,
  required final ContentNode node,

  /// Posizione nell'ordine di lettura del documento.
  required final double order,
  required final VoidCallback? onTap,
  required final Color focusColor,
}) extends StatefulWidget {
  @override
  State<LinkTarget> createState() => _LinkTargetState();
}

class _LinkTargetState() extends State<LinkTarget> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_modeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged(FocusHighlightMode _) => setState(() {});

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final onTap = widget.onTap;
    final enter = event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (event is! KeyDownEvent || !enter || onTap == null) return KeyEventResult.ignored;
    onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final level = node.headingLevel;
    return Semantics(
      container: true,
      sortKey: OrdinalSortKey(widget.order),
      link: true,
      linkUrl: Uri.tryParse(node.href!),
      label: node.label,
      header: level > 0,
      headingLevel: level > 0 ? level : null,
      onTap: widget.onTap,
      child: Focus(
        onKeyEvent: _onKey,
        onFocusChange: (_) => setState(() {}),
        child: Builder(
          builder: (context) {
            final shown =
                Focus.of(context).hasPrimaryFocus &&
                FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
            final origin = node.bounds.topLeft;
            return CustomPaint(
              foregroundPainter: shown
                  ? _RingPainter([for (final r in node.rects) r.shift(-origin)], widget.focusColor)
                  : null,
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

/// Tratto di 2 px a 2 px dai box del link, come l'anello di focus del design system.
class const _RingPainter(final List<Rect> rects, final Color color) extends CustomPainter {
  static const _width = 2.0;
  static const _offset = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    for (final r in rects) {
      canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(_offset + _width / 2), const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color || old.rects != rects;
}
