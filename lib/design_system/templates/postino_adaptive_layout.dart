import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_single_pane_layout.dart';

/// Picks the layout from the window width (Material 3 size classes):
/// below `breakpoint-expanded` (840) one pane with a modal [drawer];
/// from 840 the [drawer] is not shown here: the caller docks it once with [PostinoSidebarShell],
/// outside the pages, so it survives navigation.
// ponytail: no detail pane yet (Conversazione, #33), so the list takes the rest of the width and
// 600–839 stays one pane; add the `list-width` list + detail (LayoutTablet / LayoutDesktop) with it.
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

/// From `breakpoint-expanded` (840) docks [drawer] at `sidebar-width` (280) beside [child];
/// below it just [child]. Built once above the pages, so the [drawer] State outlives navigation.
class PostinoSidebarShell extends StatelessWidget {
  const PostinoSidebarShell({
    super.key,
    required this.drawer,
    required this.child,
  });

  final Widget drawer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < PostinoSize.breakpointExpanded) {
      return child;
    }
    final c = context.pc;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: c.borderSubtle,
                width: PostinoBorder.borderWidthHairline,
              ),
            ),
          ),
          child: DrawerTheme(
            data: const DrawerThemeData(
              width: PostinoSize.sidebarWidth,
              elevation: 0,
              shape: RoundedRectangleBorder(),
            ),
            child: drawer,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
