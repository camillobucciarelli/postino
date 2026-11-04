import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The keyboard focus indicator of every interactive component: a `focus-ring` stroke of
/// `border-width-focus` around [child], while the enclosing focusable (an InkWell, a button)
/// has focus from the keyboard. Put it inside that focusable, around its visible shape.
/// Controls with a shape of their own get it `focus-offset` outside; full-width rows ([inset])
/// get it inside their edges, where nothing clips it.
class const PostinoFocusRing({
  super.key,
  required this.child,
  this.borderRadius = BorderRadius.zero,
  this.inset = false,
}) extends StatefulWidget {
  /// Crea l'anello di focus attorno a `child`.
  this;

  /// Forma visibile attorno a cui disegnare l'anello.
  final Widget child;

  /// The shape of [child]; the ring follows it at its distance.
  final BorderRadius borderRadius;

  /// Se l'anello sta dentro i bordi (righe a tutta larghezza) invece che fuori.
  final bool inset;

  @override
  State<PostinoFocusRing> createState() => _PostinoFocusRingState();
}

class _PostinoFocusRingState() extends State<PostinoFocusRing> {
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

  @override
  Widget build(BuildContext context) {
    // Like the InkWell's own focus highlight: only when focus came from the keyboard.
    final shown =
        (Focus.maybeOf(context)?.hasPrimaryFocus ?? false) &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return CustomPaint(
      foregroundPainter: shown ? _RingPainter(context.pc.focusRing, widget.borderRadius, inset: widget.inset) : null,
      child: widget.child,
    );
  }
}

class const _RingPainter(this.color, this.radius, {required this.inset}) extends CustomPainter {
  final Color color;
  final BorderRadius radius;
  final bool inset;

  @override
  void paint(Canvas canvas, Size size) {
    const w = PostinoBorder.borderWidthFocus;
    // The stroke is centered on the path: half its width in, or the offset plus half out.
    final delta = inset ? -w / 2 : PostinoBorder.focusOffset + w / 2;
    canvas.drawRRect(
      radius.toRRect(Offset.zero & size).inflate(delta),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color || old.radius != radius || old.inset != inset;
}
