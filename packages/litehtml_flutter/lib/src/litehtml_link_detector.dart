import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Tap sui link di un documento e cursore a mano sopra di essi. Un tap fuori dai link non entra nell'arena dei gesti:
/// resta alla `SelectionArea` o a chi sta sopra.
class const LitehtmlLinkDetector({
  super.key,

  /// `href` del link nel punto (coordinate della vista), o null.
  required final String? Function(Offset position) linkAt,
  required final ValueChanged<String> onTap,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<LitehtmlLinkDetector> createState() => _LitehtmlLinkDetectorState();
}

class _LitehtmlLinkDetectorState() extends State<LitehtmlLinkDetector> {
  MouseCursor _cursor = MouseCursor.defer;

  void _setCursor(MouseCursor cursor) {
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: _cursor,
    onHover: (e) => _setCursor(widget.linkAt(e.localPosition) == null ? MouseCursor.defer : SystemMouseCursors.click),
    onExit: (_) => _setCursor(MouseCursor.defer),
    child: RawGestureDetector(
      gestures: {
        _LinkTap: GestureRecognizerFactoryWithHandlers<_LinkTap>(
          () => _LinkTap((p) => widget.linkAt(p) != null),
          (r) => r.onTapUp = (d) {
            if (widget.linkAt(d.localPosition) case final href?) widget.onTap(href);
          },
        ),
      },
      child: widget.child,
    ),
  );
}

/// Un tap che si candida solo se parte su un link.
class _LinkTap(final bool Function(Offset) _onLink) extends TapGestureRecognizer {
  @override
  bool isPointerAllowed(PointerDownEvent event) => _onLink(event.localPosition) && super.isPointerAllowed(event);
}
