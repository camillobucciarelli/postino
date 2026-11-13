import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Opens [builder]'s content in a panel anchored under the widget of [anchor] (above it when there is no room),
/// `surface-raised`, `radius-md`, `border-subtle` like PostinoMenu; under `breakpoint-medium` (600) it is a bottom
/// sheet with the same content. It is a route named [label]: Tab stays inside, Esc and a tap outside close it
/// ([barrierLabel] names the tap outside). On closing the focus goes back to [returnFocus], the control that opened it
/// (a keyboard shortcut opens it from anywhere, so the route alone would not know where to go).
Future<T?> showPostinoPopover<T>(
  BuildContext anchor, {
  required String label,
  required String barrierLabel,
  required WidgetBuilder builder,
  FocusNode? returnFocus,
  double width = 360,
}) async {
  final nav = Navigator.of(anchor);
  final T? result;
  if (MediaQuery.sizeOf(anchor).width < PostinoSize.breakpointMedium) {
    result = await showModalBottomSheet<T>(
      context: anchor,
      isScrollControlled: true,
      useSafeArea: true,
      barrierLabel: barrierLabel,
      builder: (context) => Semantics(
        namesRoute: true,
        label: label,
        explicitChildNodes: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: builder(context),
        ),
      ),
    );
  } else {
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = nav.overlay!.context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    result = await nav.push(
      RawDialogRoute<T>(
        barrierLabel: barrierLabel,
        barrierColor: Colors.transparent,
        transitionDuration: PostinoMotion.of(anchor, PostinoMotion.state),
        transitionBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
        pageBuilder: (context, _, _) {
          final c = context.pc;
          return CustomSingleChildLayout(
            delegate: _Anchored(rect, width),
            child: Semantics(
              namesRoute: true,
              scopesRoute: true,
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
  returnFocus?.requestFocus();
  return result;
}

/// Under the anchor, its right edges aligned (left when it would go off), above it when there is no room.
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
