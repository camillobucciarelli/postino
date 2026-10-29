import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_fade_through.dart';

/// A list and the item opened from it ([detail], identified by [detailKey]).
/// From `breakpoint-expanded` (840): the list at `list-width` (380) and the detail beside it,
/// [empty] when nothing is open, a fade through between details.
/// Below: the detail is a full page over the list, with the Material 3 shared axis X
/// (slide + fade); the list stays mounted under it, so going back finds it as it was.
/// The list keeps its State across both, and across a resize. Esc calls [onClose].
/// With reduced motion every change is instant.
class PostinoListDetailLayout extends StatefulWidget {
  const PostinoListDetailLayout({
    super.key,
    required this.list,
    required this.empty,
    required this.onClose,
    this.detail,
    this.detailKey,
  });

  final Widget list;
  final Widget? detail;

  /// Changes when another item opens; the outgoing [detail] must carry its own params.
  final Object? detailKey;
  final Widget empty;
  final VoidCallback onClose;

  @override
  State<PostinoListDetailLayout> createState() =>
      _PostinoListDetailLayoutState();
}

class _PostinoListDetailLayoutState extends State<PostinoListDetailLayout>
    with SingleTickerProviderStateMixin {
  static const _slide = 30.0;
  static const _fadeSplit = 0.3;

  final _listKey = GlobalKey();

  /// 0: the list; 1: the detail over it (below 840 only).
  late final _axis =
      AnimationController(
        vsync: this,
        duration: PostinoMotion.routeForward,
        reverseDuration: PostinoMotion.routeBack,
        value: widget.detail == null ? 0 : 1,
      )..addStatusListener((s) {
        if (s.isDismissed) setState(() => _closing = null);
      });

  /// The detail sliding out after it closed, with its own key.
  (Object?, Widget)? _closing;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(PostinoListDetailLayout old) {
    super.didUpdateWidget(old);
    final opened = old.detail == null && widget.detail != null;
    final closed = old.detail != null && widget.detail == null;
    if (!opened && !closed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _axis.value = opened ? 1 : 0;
      _closing = null;
    } else if (opened) {
      _closing = null;
      _axis.forward();
    } else {
      _closing = (old.detailKey, old.detail!);
      _axis.reverse();
    }
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent ||
        e.logicalKey != LogicalKeyboardKey.escape ||
        widget.detail == null) {
      return false;
    }
    widget.onClose();
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _axis.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = KeyedSubtree(key: _listKey, child: widget.list);
    if (MediaQuery.sizeOf(context).width >= PostinoSize.breakpointExpanded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: PostinoSize.listWidth, child: list),
          SizedBox(
            width: PostinoBorder.borderWidthHairline,
            child: ColoredBox(color: context.pc.borderSubtle),
          ),
          Expanded(
            child: PostinoFadeThrough(
              transitionKey: widget.detailKey ?? const _Empty(),
              child: widget.detail ?? widget.empty,
            ),
          ),
        ],
      );
    }
    final (key, detail) = widget.detail != null
        ? (widget.detailKey, widget.detail!)
        : _closing ?? (null, null);
    return AnimatedBuilder(
      animation: _axis,
      builder: (context, _) {
        final t = _axis.value;
        final move = PostinoMotion.emphasized.transform(t);
        final listOut = (t / _fadeSplit).clamp(0.0, 1.0);
        final detailIn = ((t - _fadeSplit) / (1 - _fadeSplit)).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Covered, the list leaves painting and tickers but keeps its State (scroll, streams).
            Offstage(
              offstage: detail != null && t == 1,
              child: TickerMode(
                enabled: detail == null || t < 1,
                child: IgnorePointer(
                  ignoring: detail != null,
                  child: Transform.translate(
                    offset: Offset(-_slide * move, 0),
                    child: Opacity(opacity: 1 - listOut, child: list),
                  ),
                ),
              ),
            ),
            if (detail != null)
              Transform.translate(
                offset: Offset(_slide * (1 - move), 0),
                child: Opacity(
                  opacity: detailIn,
                  child: KeyedSubtree(key: ValueKey(key), child: detail),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The [PostinoListDetailLayout.empty] pane's transition key.
class _Empty {
  const _Empty();
}
