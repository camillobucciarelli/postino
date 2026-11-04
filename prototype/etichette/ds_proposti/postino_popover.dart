// PROTOTIPO (#106) — componente proposto per il design system (molecola).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// A non-modal-looking panel anchored under the widget of [anchor] (above it when there is no room),
/// `surface-raised`, `radius-md`, `border-subtle` like PostinoMenu. It is a route: Tab stays inside,
/// Esc and a click outside close it; the caller returns the focus to the anchor after the Future.
Future<T?> showPostinoPopover<T>(
  BuildContext anchor, {
  required String label,
  required WidgetBuilder builder,
  double width = 340,
}) {
  final nav = Navigator.of(anchor);
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = nav.overlay!.context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  return nav.push(
    RawDialogRoute<T>(
      barrierLabel: 'Chiudi $label',
      barrierColor: Colors.transparent,
      transitionDuration: PostinoMotion.of(anchor, PostinoMotion.state),
      transitionBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
      pageBuilder: (context, _, _) {
        final c = context.pc;
        return CustomSingleChildLayout(
          delegate: _Anchored(rect, width),
          child: Semantics(
            namesRoute: true,
            label: label,
            explicitChildNodes: true,
            child: Material(
              color: c.surfaceRaised,
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
                side: BorderSide(color: c.borderSubtle),
              ),
              child: builder(context),
            ),
          ),
        );
      },
    ),
  );
}

class const _Anchored(final Rect anchor, final double width) extends SingleChildLayoutDelegate {
  static const _margin = PostinoSpacing.s4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final s = constraints.biggest;
    final room = math.max(s.height - anchor.bottom, anchor.top) - 2 * _margin;
    return BoxConstraints(maxWidth: math.min(width, s.width - 2 * _margin), maxHeight: math.max(room, 200));
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = anchor.right - child.width < _margin ? anchor.left : anchor.right - child.width;
    final below = anchor.bottom + PostinoSpacing.s1;
    final y = below + child.height <= size.height - _margin ? below : anchor.top - PostinoSpacing.s1 - child.height;
    return Offset(
      x.clamp(_margin, math.max(_margin, size.width - child.width - _margin)),
      y.clamp(_margin, math.max(_margin, size.height - child.height - _margin)),
    );
  }

  @override
  bool shouldRelayout(_Anchored old) => old.anchor != anchor || old.width != width;
}
