import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_focus_ring.dart';

/// The vertical divider between two panes that the user drags to resize the first one.
/// It draws the pane border (`border-subtle` hairline) with a grip in `border-strong` (3:1 on the panes)
/// and reads as an adjustable value: [value] pixels between [min] and [max], [label] as its name.
///
/// Mouse and trackpad: drag ([onChanged] live, [onChangeEnd] when the drag ends), double click ([onReset]).
/// Keyboard, with the focus on it: left/right by `list-width-step`, Home [min], End [max] (all through
/// [onChangeEnd]); the arrows stop here and move nothing else. VoiceOver: increase and decrease by the same step.
class PostinoResizeHandle extends StatefulWidget {
  const PostinoResizeHandle({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.valueLabel,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
  });

  final double value;
  final double min;
  final double max;

  /// The accessible name, e.g. "Larghezza lista".
  final String label;

  /// The accessible value at a width, e.g. "380 pixel".
  final String Function(double value) valueLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;

  @override
  State<PostinoResizeHandle> createState() => _PostinoResizeHandleState();
}

class _PostinoResizeHandleState extends State<PostinoResizeHandle> {
  final _focus = FocusNode(debugLabel: 'PostinoResizeHandle');
  bool _hover = false;
  bool _dragging = false;
  double _from = 0;
  double _moved = 0;
  double _current = 0;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double _clamp(double v) =>
      v.clamp(widget.min, widget.max < widget.min ? widget.min : widget.max);

  void _step(double delta) => widget.onChangeEnd(_clamp(widget.value + delta));

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _step(-PostinoSize.listWidthStep);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _step(PostinoSize.listWidthStep);
    } else if (key == LogicalKeyboardKey.home) {
      widget.onChangeEnd(widget.min);
    } else if (key == LogicalKeyboardKey.end) {
      widget.onChangeEnd(_clamp(widget.max));
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      // Not ours, but not the list's either: they stop here.
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _dragStart(DragStartDetails _) {
    _focus.requestFocus();
    setState(() {
      _dragging = true;
      _from = _current = widget.value;
      _moved = 0;
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    _moved += d.primaryDelta ?? 0;
    final v = _clamp(_from + _moved);
    if (v == _current) return;
    _current = v;
    widget.onChanged(v);
  }

  void _dragEnd([Object? _]) {
    setState(() => _dragging = false);
    if (_current != _from) widget.onChangeEnd(_current);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final active = _hover || _dragging;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        label: widget.label,
        value: widget.valueLabel(widget.value),
        increasedValue: widget.valueLabel(
          _clamp(widget.value + PostinoSize.listWidthStep),
        ),
        decreasedValue: widget.valueLabel(
          _clamp(widget.value - PostinoSize.listWidthStep),
        ),
        onIncrease: () => _step(PostinoSize.listWidthStep),
        onDecrease: () => _step(-PostinoSize.listWidthStep),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _dragStart,
            onHorizontalDragUpdate: _dragUpdate,
            onHorizontalDragEnd: _dragEnd,
            onHorizontalDragCancel: _dragEnd,
            onDoubleTap: widget.onReset,
            // The ring is drawn inside the handle's own box: no pane border clips it.
            child: PostinoFocusRing(
              inset: true,
              child: SizedBox(
                width: PostinoSize.resizeHandleWidth,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: active
                          ? PostinoBorder.borderWidthFocus
                          : PostinoBorder.borderWidthHairline,
                      height: double.infinity,
                      child: ColoredBox(
                        color: active ? c.borderStrong : c.borderSubtle,
                      ),
                    ),
                    SizedBox(
                      width: PostinoSize.resizeGripWidth,
                      height: PostinoSize.resizeGripHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.borderStrong,
                          borderRadius: BorderRadius.circular(
                            PostinoRadius.full,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
