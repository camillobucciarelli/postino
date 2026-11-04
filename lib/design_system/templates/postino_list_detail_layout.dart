import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/postino_resize_handle.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_tokens.dart';
import 'postino_fade_through.dart';

/// The width the list shows: the [preferred] one limited to the window, `list-width-min` (280) up to
/// `list-width-max-fraction` (50%) of [window]. If the two cross (a narrow window) the minimum wins.
double shownListWidth(double preferred, double window) => preferred.clamp(
  PostinoSize.listWidthMin,
  math.max(PostinoSize.listWidthMin, window * PostinoSize.listWidthMaxFraction),
);

/// A list and the item opened from it ([detail], identified by [detailKey]).
/// From `breakpoint-list-detail` (900): the list and the detail beside it, [empty] when nothing is open,
/// a fade through between details. A [PostinoResizeHandle] divides them: the user drags it (or uses the keyboard)
/// to set the list width, the preferred one (default `list-width`, 380, or [listWidth] saved earlier); what is shown is
/// [shownListWidth] of it, so a narrow window never changes the preference. Only the user's actions call [onListWidthChanged],
/// once per drag, at its end.
/// Below 900: the detail is a full page over the list, with the Material 3 shared axis X
/// (slide + fade); the list stays mounted under it, so going back finds it as it was.
/// The list and the open detail keep their State across both, and across a resize. Esc calls [onClose].
/// With reduced motion every change is instant.
class const PostinoListDetailLayout({
  super.key,

  /// La lista, sempre presente sotto il dettaglio su schermi stretti.
  required final Widget list,

  /// Pannello mostrato quando nessun dettaglio è aperto, sulle finestre larghe.
  required final Widget empty,

  /// Chiamato quando l'utente chiude il dettaglio, con il tasto Esc.
  required final VoidCallback onClose,

  /// Il dettaglio aperto, o null se nessun elemento è aperto.
  final Widget? detail,

  /// Changes when another item opens; the outgoing [detail] must carry its own params.
  final Object? detailKey,

  /// The preferred list width saved by an earlier run; null: the default.
  final double? listWidth,

  /// The user chose a new preferred width (end of a drag, key, double click): save it.
  final ValueChanged<double>? onListWidthChanged,

  /// Accessible name and value of the divider ("Larghezza lista", "380 pixel").
  required final String resizeLabel,

  /// Costruisce il testo letto per la larghezza attuale della lista.
  required final String Function(double width) resizeValueLabel,
}) extends StatefulWidget {
  /// Crea il layout lista e dettaglio.
  this;

  @override
  State<PostinoListDetailLayout> createState() => _PostinoListDetailLayoutState();
}

class _PostinoListDetailLayoutState() extends State<PostinoListDetailLayout> with SingleTickerProviderStateMixin {
  static const _slide = 30.0;
  static const _fadeSplit = 0.3;

  final _listKey = GlobalKey();

  /// Marks the open detail, to hand it the focus when it is the only thing on screen.
  final _detailFocus = FocusNode(canRequestFocus: false, skipTraversal: true);
  bool? _wasLarge;

  /// What the user chose (never limited), and the width of a drag in progress (limited).
  late double _preferred = widget.listWidth ?? PostinoSize.listWidth;
  double? _dragging;

  void _choose(double shown) {
    setState(() {
      _preferred = shown;
      _dragging = null;
    });
    widget.onListWidthChanged?.call(shown);
  }

  /// One per open item: the two panes and the full page differ in structure, so only a
  /// GlobalKey carries the detail State (scroll, expansions) across 900.
  final _detailKeys = <Object?, GlobalKey>{};

  Widget _keyed(Object? key, Widget detail) =>
      KeyedSubtree(key: _detailKeys.putIfAbsent(key, GlobalKey.new), child: detail);

  /// 0: the list; 1: the detail over it (below 900 only).
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final large = MediaQuery.sizeOf(context).width >= PostinoSize.breakpointListDetail;
    // Narrowed with a detail open: it becomes the full page, so the focus goes to it.
    if ((_wasLarge ?? false) && !large && widget.detail != null) _focusDetail();
    _wasLarge = large;
  }

  /// One pane only: the full-page detail takes the focus, not the list hidden under it.
  /// Two panes leave the focus where it is (on the list's selected row).
  void _focusDetail() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || widget.detail == null || MediaQuery.sizeOf(context).width >= PostinoSize.breakpointListDetail) {
      return;
    }
    // The back button, named explicitly: the controls of the AppBar come first. A control scrolled
    // under the bar has a positive top, so position alone cannot tell it from the button.
    // Without an AppBar (two panes never get here) the first on screen wins; a header scrolled
    // out above (negative top) is mounted but not on screen: skipped.
    final all = _detailFocus.traversalDescendants;
    final bar = all.where((n) => n.context?.findAncestorWidgetOfExactType<AppBar>() != null).toList();
    final nodes = (bar.isNotEmpty ? bar : all.where((n) => n.rect.top >= 0).toList())
      ..sort((a, b) {
        final byTop = a.rect.top.compareTo(b.rect.top);
        return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
      });
    nodes.firstOrNull?.requestFocus();
  });

  @override
  void didUpdateWidget(PostinoListDetailLayout old) {
    super.didUpdateWidget(old);
    if (widget.detail != null && (old.detail == null || old.detailKey != widget.detailKey)) {
      _focusDetail();
    }
    // The outgoing detail may still be on screen; older ones are gone.
    _detailKeys.removeWhere((k, _) => k != widget.detailKey && k != old.detailKey);
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
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.escape || widget.detail == null) {
      return false;
    }
    final focus = primaryFocus?.context;
    // A dialog (or any route above this one) owns the Esc.
    if (focus != null && ModalRoute.of(focus) != ModalRoute.of(context)) {
      return false;
    }
    // A selection in the Conversazione takes the first Esc.
    if (focus != null) {
      const clear = PostinoClearSelectionIntent();
      if (Actions.maybeFind<PostinoClearSelectionIntent>(focus) case final action? when action.isEnabled(clear)) {
        Actions.invoke(focus, clear);
        return true;
      }
    }
    widget.onClose();
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _axis.dispose();
    _detailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = KeyedSubtree(key: _listKey, child: widget.list);
    final window = MediaQuery.sizeOf(context).width;
    if (window >= PostinoSize.breakpointListDetail) {
      final max = math.max(PostinoSize.listWidthMin, window * PostinoSize.listWidthMaxFraction);
      final shown = _dragging ?? shownListWidth(_preferred, window);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: shown, child: list),
          PostinoResizeHandle(
            value: shown,
            min: PostinoSize.listWidthMin,
            max: max,
            label: widget.resizeLabel,
            valueLabel: widget.resizeValueLabel,
            onChanged: (w) => setState(() => _dragging = w),
            onChangeEnd: _choose,
            onDragEnd: () => setState(() => _dragging = null),
            onReset: () => _choose(PostinoSize.listWidth),
          ),
          Expanded(
            // The empty state has no Scaffold of its own: without a Material its Text gets the debug yellow underline.
            child: Material(
              type: MaterialType.transparency,
              child: PostinoFadeThrough(
                transitionKey: widget.detailKey ?? const _Empty(),
                child: widget.detail != null ? _keyed(widget.detailKey, widget.detail!) : widget.empty,
              ),
            ),
          ),
        ],
      );
    }
    final (key, detail) = widget.detail != null ? (widget.detailKey, widget.detail!) : _closing ?? (null, null);
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
                  child: Focus(focusNode: _detailFocus, child: _keyed(key, detail)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The [PostinoListDetailLayout.empty] pane's transition key.
class const _Empty();
