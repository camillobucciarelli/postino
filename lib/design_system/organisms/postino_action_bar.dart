import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_button.dart';
import '../atoms/postino_icon_button.dart';
import '../atoms/postino_shortcut_tooltip.dart';
import '../molecules/postino_menu.dart';
import '../molecules/postino_snackbar_lift.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_action_bar_fit.dart';
import 'postino_bar_action.dart';

export 'postino_bar_action.dart';

/// Where a PostinoActionBar sits.
enum PostinoActionBarPlacement() {
  /// In the bar on top (PostinoAppBar's `toolbar`): the groups apart by a divider.
  top,

  /// Fixed under a detail: the surface fill and a hairline on top, the groups at the two ends, clear of the gesture
  /// bar (`viewPadding.bottom`, the surface going on under it); the snackbars show above it.
  bottom,
}

/// The Azioni of a detail as icon buttons, in [groups] (Archivia · Elimina | Stella · Letto · Etichette | Inoltra ·
/// Rispondi a tutti · Rispondi). With no room the actions with an `overflow` move, the lowest first, into one «more»
/// menu ([moreLabel]) at the end of the group of the first to go; the others stay. The `primary` action is a filled
/// button; at the [PostinoActionBarPlacement.bottom] it has its label too, from 360 wide and when it fits.
class const PostinoActionBar({
  super.key,

  /// Le Azioni, a gruppi, nell'ordine mostrato.
  required final List<List<PostinoBarAction>> groups,

  /// Nome del menu delle Azioni che non ci stanno («Altre azioni»).
  required final String moreLabel,

  /// Dove sta la barra.
  final PostinoActionBarPlacement placement = PostinoActionBarPlacement.top,

  /// On top, the groups at the end of the bar (beside a back arrow) instead of its start.
  final bool alignEnd = false,
}) extends StatefulWidget {
  /// Crea la barra delle Azioni.
  this;

  /// From this width the primary action of a bottom bar shows its label.
  static const double extendedFrom = 360;

  @override
  State<PostinoActionBar> createState() => _PostinoActionBarState();
}

class _PostinoActionBarState() extends State<PostinoActionBar> {
  /// The lift of the snackbars this bottom bar holds, kept for dispose (no lookup there).
  ValueNotifier<(Object?, double)>? _lift;

  bool get _bottom => widget.placement == PostinoActionBarPlacement.bottom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lift = PostinoSnackbarLift.of(context);
  }

  /// After the layout: the snackbars stand on this bar (its height above the safe area the Scaffold leaves anyway).
  void _report(Duration _) {
    final lift = _lift;
    if (!mounted || lift == null || !_bottom) return;
    final h = (context.size?.height ?? 0) - MediaQuery.viewPaddingOf(context).bottom;
    if (lift.value != (this, h)) lift.value = (this, h);
  }

  @override
  void dispose() {
    final lift = _lift;
    // Not during the unmount: the tree is locked. A bar that came meanwhile has taken it already.
    if (lift != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (lift.value.$1 == this) lift.value = (null, 0);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bottom) WidgetsBinding.instance.addPostFrameCallback(_report);
    final c = context.pc;
    final viewBottom = _bottom ? MediaQuery.viewPaddingOf(context).bottom : 0.0;
    final side = _bottom ? PostinoSpacing.s2 : 0.0;
    final bar = LayoutBuilder(
      builder: (context, box) {
        // The bar's room inside its side padding; the 360 of the label is the whole bar's.
        final width = box.maxWidth;
        // Archivia and Elimina (the first group of a bottom bar) stand apart, so a thumb does not pick the wrong one.
        final gap = _bottom ? PostinoSpacing.s2 * math.max(0, widget.groups.first.length - 1) : 0.0;
        final fit = fitActionBar(
          widget.groups,
          width - gap - (_bottom ? PostinoSpacing.s4 : 0),
          divider: _bottom ? 0 : _dividerWidth,
          extendedPrimary: _bottom && box.maxWidth + 2 * side >= PostinoActionBar.extendedFrom
              ? _extendedWidth(context)
              : 0,
        );
        final groups = [
          for (final (i, g) in fit.shown.indexed)
            [
              for (final a in g) _button(a, extended: fit.extended),
              if (i == fit.menuGroup && fit.more.isNotEmpty)
                PostinoMenu(
                  label: widget.moreLabel,
                  items: [
                    for (final a in fit.more)
                      PostinoMenuItem(label: a.label, icon: a.icon, onPressed: a.onPressed, shortcut: a.shortcut),
                  ],
                ),
            ],
        ].where((g) => g.isNotEmpty).toList();
        final children = <Widget>[];
        for (final (i, g) in groups.indexed) {
          if (i > 0 && _bottom) children.add(const Spacer());
          if (i > 0 && !_bottom && fit.dividers) children.add(_Divider(color: c.borderSubtle));
          children.addAll(_bottom && i == 0 ? _spaced(g) : g);
        }
        return Row(
          mainAxisAlignment: widget.alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: children,
        );
      },
    );
    if (!_bottom) return bar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, PostinoSpacing.s2, side, PostinoSpacing.s2 + viewBottom),
        child: bar,
      ),
    );
  }

  List<Widget> _spaced(List<Widget> g) => [
    for (final (i, w) in g.indexed) ...[if (i > 0) const SizedBox(width: PostinoSpacing.s2), w],
  ];

  Widget _button(PostinoBarAction a, {required bool extended}) {
    if (a.primary && extended) {
      final button = PostinoButton(label: a.label, icon: a.icon, onPressed: a.onPressed, focusNode: a.focusNode);
      return KeyedSubtree(
        key: a.key,
        child: switch (a.shortcut) {
          null => button,
          final keys => PostinoShortcutTooltip(label: a.label, shortcut: keys, child: button),
        },
      );
    }
    return PostinoIconButton(
      key: a.key,
      icon: a.icon,
      label: a.label,
      onPressed: a.onPressed,
      focusNode: a.focusNode,
      shortcut: a.shortcut,
      selected: a.selected,
      primary: a.primary,
    );
  }

  /// The primary action with its label: the icon, the gap and the label between the button's paddings.
  double _extendedWidth(BuildContext context) {
    final primary = widget.groups.expand((g) => g).where((a) => a.primary).firstOrNull;
    if (primary == null) return 0;
    final p = TextPainter(
      text: TextSpan(text: primary.label, style: PostinoText.label),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final w = p.width;
    p.dispose();
    return 2 * PostinoSpacing.s4 + PostinoSize.iconMd + PostinoSpacing.s2 + w;
  }
}

/// 1 wide, `space-2` on each side.
const double _dividerWidth = 1 + 2 * PostinoSpacing.s2;

class const _Divider({required final Color color}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s2),
    child: SizedBox(
      width: 1,
      height: PostinoSize.iconLg,
      child: ColoredBox(color: color),
    ),
  );
}
