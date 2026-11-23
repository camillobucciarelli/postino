import 'dart:math' as math;

// ignore: deprecated_member_use
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
/// goes back and nothing happens. When [onSwipe] says the Azione takes the row away (Archivia, Elimina), the row goes
/// on off the screen on that side (`swipeDismiss`), the Azione's colour behind it, untouchable, until the owner
/// rebuilds it with [away] false (the row stayed, or came back with Annulla): then it is in place at once, not sliding
/// back. With reduced motion it is in place at once on release. Pointer only: the same Azioni must be reachable otherwise (menu, keyboard, semantic actions
/// of the child).
class const PostinoSwipeRow({
  super.key,

  /// Azione di un trascinamento verso sinistra.
  required final PostinoSwipeAction left,

  /// Azione di un trascinamento verso destra.
  required final PostinoSwipeAction right,

  /// Chiamata al rilascio oltre la soglia; true se l'Azione toglie la riga, che allora esce dallo schermo.
  required final bool Function(PostinoSwipeSide side) onSwipe,

  /// Il proprietario tiene la riga fuori dallo schermo, dopo uno swipe che la toglie, finché non è uscita dalla lista.
  final bool away = false,

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

  /// Where the row went off the screen after a swipe that takes it away; null while it is in place.
  double? _gone;

  /// Back in place at once (no animation) on this build: the row came back while off the screen.
  bool _snap = false;

  bool get _armed => _drag.abs() >= PostinoSize.swipeThreshold;

  /// Where the row is: the finger's travel, slowed down past the threshold.
  double get _shift {
    if (_gone case final gone?) return gone;
    final over = math.max(0, _drag.abs() - PostinoSize.swipeThreshold);
    return _drag.sign * (math.min(_drag.abs(), PostinoSize.swipeThreshold) + over * PostinoSize.swipeResistance);
  }

  void _update(DragUpdateDetails d) {
    // Off the screen, on its way out: nothing to drag.
    if (_gone != null) return;
    setState(() {
      _snap = false;
      _dragging = true;
      _drag += d.delta.dx;
      if (_drag != 0) _side = _drag < 0 ? PostinoSwipeSide.left : PostinoSwipeSide.right;
    });
  }

  void _cancel() => _release(act: false);

  void _end(DragEndDetails _) => _release(act: true);

  void _release({required bool act}) {
    final side = _side;
    final armed = _armed;
    final takesAway = act && armed && side != null && widget.onSwipe(side);
    // With reduced motion the row is back at once, and gone with the list's row.
    final still = PostinoMotion.of(context, PostinoMotion.swipeDismiss) == Duration.zero;
    final out = takesAway && !still;
    setState(() {
      _dragging = false;
      _drag = 0;
      if (out) {
        _gone = (side == PostinoSwipeSide.left ? -1 : 1) * context.size!.width;
      } else if (still) {
        _side = null;
      }
    });
  }

  @override
  void didUpdateWidget(PostinoSwipeRow old) {
    super.didUpdateWidget(old);
    // The row stayed, or came back (Annulla): in place at once, the list fades it in.
    if (!widget.away && _gone != null) {
      _gone = null;
      _side = null;
      _snap = true;
    }
  }

  Widget _behind(PostinoColors c, PostinoSwipeSide side) {
    final action = side == PostinoSwipeSide.left ? widget.left : widget.right;
    final armed = (_dragging && _armed) || _gone != null;
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
              duration: _dragging || _snap
                  ? Duration.zero
                  : PostinoMotion.of(context, _gone == null ? PostinoMotion.swipeSettle : PostinoMotion.swipeDismiss),
              curve: PostinoMotion.swipeRelease,
              transform: Matrix4.translationValues(_shift, 0, 0),
              onEnd: () {
                // Without motion it ends inside the build that set it: [_release] or [didUpdateWidget] did it all.
                // Off the screen it stays until the owner says.
                if (_dragging || _snap || _gone != null || !mounted) return;
                if (PostinoMotion.of(context, PostinoMotion.swipeSettle) == Duration.zero) return;
                setState(() => _side = null);
              },
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
