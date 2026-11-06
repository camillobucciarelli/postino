import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Which way a row is dragged: the finger moves to the left or to the right.
enum PostinoSwipeSide() {
  /// Il dito va a sinistra.
  left,

  /// Il dito va a destra.
  right,
}

/// The colour an Azione takes once armed.
enum PostinoSwipeTone() {
  /// Archivia.
  archive,

  /// Elimina.
  delete,

  /// Segna come letto/non letto.
  read,

  /// Stella.
  star,

  /// Applica Etichetta.
  label,
}

/// What a swipe shows behind the row: the Azione's label, icon and tone.
typedef PostinoSwipeAction = ({String label, PostinoIconData icon, PostinoSwipeTone tone});

/// A row that follows a horizontal drag and shows the Azione of that direction behind it (SwipeActions): neutral
/// until the drag passes `PostinoSize.swipeThreshold`, then in the Azione's colour; past it the row resists
/// (`swipeResistance`). Released armed, [onSwipe] is called with the side; released short of the threshold the row
/// goes back and nothing happens. Pointer only: the same Azioni must be reachable otherwise (menu, keyboard,
/// semantic actions of the child).
class const PostinoSwipeRow({
  super.key,

  /// Azione di un trascinamento verso sinistra.
  required final PostinoSwipeAction left,

  /// Azione di un trascinamento verso destra.
  required final PostinoSwipeAction right,

  /// Chiamata al rilascio oltre la soglia.
  required final void Function(PostinoSwipeSide side) onSwipe,

  /// La riga; opaca, perché copre lo sfondo dell'Azione.
  required final Widget child,
}) extends StatefulWidget {
  /// Crea la riga scorrevole.
  this;

  @override
  State<PostinoSwipeRow> createState() => _PostinoSwipeRowState();
}

class _PostinoSwipeRowState() extends State<PostinoSwipeRow> {
  /// The finger's travel: negative to the left.
  double _drag = 0;
  bool _dragging = false;

  /// The side whose Azione is behind the row, while it shows.
  PostinoSwipeSide? _side;

  bool get _armed => _drag.abs() >= PostinoSize.swipeThreshold;

  /// Where the row is: the finger's travel, slowed down past the threshold.
  double get _shift {
    final over = math.max(0, _drag.abs() - PostinoSize.swipeThreshold);
    return _drag.sign * (math.min(_drag.abs(), PostinoSize.swipeThreshold) + over * PostinoSize.swipeResistance);
  }

  void _update(DragUpdateDetails d) => setState(() {
    _dragging = true;
    _drag += d.delta.dx;
    if (_drag != 0) _side = _drag < 0 ? PostinoSwipeSide.left : PostinoSwipeSide.right;
  });

  void _cancel() => _release(act: false);

  void _end(DragEndDetails _) => _release(act: true);

  void _release({required bool act}) {
    final side = _side;
    final armed = _armed;
    setState(() {
      _dragging = false;
      _drag = 0;
      if (PostinoMotion.of(context, PostinoMotion.swipeSettle) == Duration.zero) _side = null;
    });
    if (act && armed && side != null) widget.onSwipe(side);
  }

  Widget _behind(PostinoColors c, PostinoSwipeSide side) {
    final action = side == PostinoSwipeSide.left ? widget.left : widget.right;
    final armed = _dragging && _armed;
    final bg = !armed
        ? c.swipeNeutralBg
        : switch (action.tone) {
            PostinoSwipeTone.archive => c.swipeArchiveBg,
            PostinoSwipeTone.delete => c.swipeDeleteBg,
            PostinoSwipeTone.read || PostinoSwipeTone.label => c.swipeReadBg,
            PostinoSwipeTone.star => c.swipeStarBg,
          };
    final fg = !armed ? c.swipeFgIdle : (action.tone == PostinoSwipeTone.star ? c.swipeStarFg : c.swipeFg);
    return Positioned.fill(
      child: ExcludeSemantics(
        child: ColoredBox(
          color: bg,
          child: Align(
            alignment: side == PostinoSwipeSide.left ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: PostinoSpacing.s2,
                children: [
                  PostinoIcon(action.icon, size: PostinoSize.iconLg, color: fg),
                  Text(action.label, style: PostinoText.label.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final side = _side;
    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: _cancel,
      child: ClipRect(
        child: Stack(
          children: [
            if (side != null) _behind(context.pc, side),
            AnimatedContainer(
              duration: _dragging ? Duration.zero : PostinoMotion.of(context, PostinoMotion.swipeSettle),
              curve: PostinoMotion.swipeRelease,
              transform: Matrix4.translationValues(_shift, 0, 0),
              onEnd: () {
                if (!_dragging && mounted) setState(() => _side = null);
              },
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
