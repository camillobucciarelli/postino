import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import '../organisms/postino_navigation_drawer.dart' show PostinoSidebarScope;
import 'postino_single_pane_layout.dart';

/// Picks the layout from the window width (Material 3 size classes):
/// below `breakpoint-expanded` (840) one pane with a modal [drawer];
/// from 840 the [drawer] is not shown here: the caller docks it once with [PostinoSidebarShell],
/// outside the pages, so it survives navigation.
/// The list + detail split is [PostinoListDetailLayout]'s, around this.
// ponytail: 600–839 stays one pane (the Conversazione a full page); LayoutTablet's two panes if tablets need them.
class PostinoAdaptiveLayout extends StatelessWidget {
  const PostinoAdaptiveLayout({
    super.key,
    required this.appBar,
    required this.body,
    required this.drawer,
    this.banners = const [],
  });

  final Widget appBar;
  final Widget body;
  final Widget drawer;
  final List<Widget> banners;

  @override
  Widget build(BuildContext context) {
    final docked =
        MediaQuery.sizeOf(context).width >= PostinoSize.breakpointExpanded;
    return PostinoSinglePaneLayout(
      appBar: appBar,
      body: body,
      drawer: docked ? null : drawer,
      banners: banners,
    );
  }
}

/// Opens or closes the docked sidebar (the shortcut of the Posta views sends it).
class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

/// From `breakpoint-expanded` (840) docks [drawer] beside [child]; below it just [child], in the same
/// tree so its State survives the resize. Built once above the pages, so the [drawer] State outlives navigation.
/// Docked, the sidebar is `sidebar-width` (280) from `breakpoint-sidebar-collapse` (1000) and icons only
/// (`sidebar-collapsed-width`, 72) below it. A manual choice ([expanded] at the start, then the button or
/// [ToggleSidebarIntent]) holds until the window crosses 1000 either way; each change goes to [onExpandedChanged]
/// (null: no choice, the width decides).
class PostinoSidebarShell extends StatefulWidget {
  const PostinoSidebarShell({
    super.key,
    required this.drawer,
    required this.child,
    required this.closeLabel,
    required this.openLabel,
    this.expanded,
    this.onExpandedChanged,
  });

  final Widget drawer;
  final Widget child;

  /// The button's name while the sidebar is extended / icons only.
  final String closeLabel;
  final String openLabel;
  final bool? expanded;
  final ValueChanged<bool?>? onExpandedChanged;

  @override
  State<PostinoSidebarShell> createState() => _PostinoSidebarShellState();
}

class _PostinoSidebarShellState extends State<PostinoSidebarShell> {
  late bool? _manual = widget.expanded;
  double? _width;

  static bool _extended(double width) =>
      width >= PostinoSize.breakpointSidebarCollapse;

  void _choose(bool? expanded) {
    setState(() => _manual = expanded);
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    // Crossing the threshold either way gives the decision back to the width.
    if (_manual != null &&
        _width != null &&
        _extended(_width!) != _extended(width)) {
      _manual = null;
      widget.onExpandedChanged?.call(null);
    }
    _width = width;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final docked = width >= PostinoSize.breakpointExpanded;
    final expanded = _manual ?? _extended(width);
    void toggle() => _choose(!expanded);
    final c = context.pc;
    // Always the same Row, the drawer slot only when docked: crossing 840 keeps the [child] State
    // (scroll, expansions, an open Conversazione).
    return Actions(
      actions: {
        ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
          onInvoke: (_) {
            if (docked) toggle();
            return null;
          },
        ),
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (docked)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: c.borderSubtle,
                    width: PostinoBorder.borderWidthHairline,
                  ),
                ),
              ),
              child: PostinoSidebarScope(
                collapsed: !expanded,
                toggleLabel: expanded ? widget.closeLabel : widget.openLabel,
                toggle: toggle,
                child: DrawerTheme(
                  data: DrawerThemeData(
                    width: expanded
                        ? PostinoSize.sidebarWidth
                        : PostinoSize.sidebarCollapsedWidth,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: widget.drawer,
                ),
              ),
            ),
          Expanded(key: const ValueKey('content'), child: widget.child),
        ],
      ),
    );
  }
}
