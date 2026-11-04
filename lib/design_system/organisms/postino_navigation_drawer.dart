import 'package:flutter/material.dart';

import '../atoms/postino_icon_button.dart';
import '../molecules/postino_drawer_item.dart';
import '../molecules/postino_drawer_item_tile.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

// The destination type stays where consumers of the drawer find it.
export '../molecules/postino_drawer_item.dart' show PostinoDrawerItem;

/// What the drawer docked by `PostinoSidebarShell` knows: whether it shows icons only,
/// and the button that opens or closes it (named [toggleLabel], what it will do).
class PostinoSidebarScope extends InheritedWidget {
  const PostinoSidebarScope({
    super.key,
    required this.collapsed,
    required this.toggleLabel,
    required this.toggle,
    required super.child,
  });

  final bool collapsed;
  final String toggleLabel;
  final VoidCallback toggle;

  /// Null for a modal drawer: always extended, no button.
  static PostinoSidebarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PostinoSidebarScope>();

  @override
  bool updateShouldNotify(PostinoSidebarScope old) =>
      collapsed != old.collapsed || toggleLabel != old.toggleLabel;
}

class PostinoDrawerSection {
  const PostinoDrawerSection({this.title, required this.items});
  final String? title;
  final List<PostinoDrawerItem> items;
}

/// Mailboxes and Etichette: a modal drawer from the left (tapping an item closes it), or the docked sidebar,
/// which (see [PostinoSidebarScope]) has a button to open and close it and, collapsed, shows only icons.
/// The highlight of the active item is one box under the list that slides to the new item.
class PostinoNavigationDrawer extends StatefulWidget {
  const PostinoNavigationDrawer({super.key, required this.sections});

  final List<PostinoDrawerSection> sections;

  @override
  State<PostinoNavigationDrawer> createState() =>
      _PostinoNavigationDrawerState();
}

class _PostinoNavigationDrawerState extends State<PostinoNavigationDrawer> {
  final _stack = GlobalKey();
  final _itemKeys = <int, GlobalKey>{};
  Rect? _active;
  var _slide = false;

  void _measure(int? index) {
    if (!mounted) return;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    final item = index == null
        ? null
        : _itemKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
    final rect = stack == null || item == null || !item.attached
        ? null
        : item.localToGlobal(Offset.zero, ancestor: stack) & item.size;
    if (rect == _active) return;
    // The first position (or one after no active item) is placed, not slid to.
    setState(() {
      _slide = _active != null && rect != null;
      _active = rect;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final sections = widget.sections;
    final scope = PostinoSidebarScope.maybeOf(context);
    final collapsed = scope?.collapsed ?? false;
    var n = 0;
    int? activeIndex;
    for (final s in sections) {
      for (final item in s.items) {
        if (item.active) activeIndex = n;
        n++;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(activeIndex));
    n = 0;
    // Width and shape come from the DrawerTheme: modal by default, docked in PostinoAdaptiveLayout.
    return Drawer(
      backgroundColor: c.drawerBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PostinoSpacing.s3),
          children: [
            if (scope != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: PostinoSpacing.s2),
                  child: PostinoIconButton(
                    icon: PostinoIcons.sidebar,
                    label: scope.toggleLabel,
                    onPressed: scope.toggle,
                  ),
                ),
              ),
            Stack(
              key: _stack,
              fit: StackFit.passthrough,
              // The outer focus ring of a rail icon is drawn outside its box.
              clipBehavior: Clip.none,
              children: [
                if (_active case final r?)
                  AnimatedPositioned(
                    left: r.left,
                    top: r.top,
                    width: r.width,
                    height: r.height,
                    duration: PostinoMotion.of(
                      context,
                      _slide ? PostinoMotion.menuIndicator : Duration.zero,
                    ),
                    curve: PostinoMotion.emphasized,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.drawerItemBgActive,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(PostinoRadius.sm),
                        ),
                      ),
                    ),
                  ),
                Column(
                  children: [
                    for (final (i, s) in sections.indexed)
                      Container(
                        margin: EdgeInsets.only(
                          top: i == 0 ? 0 : PostinoSpacing.s2,
                        ),
                        padding: const EdgeInsets.only(top: PostinoSpacing.s2),
                        decoration: i == 0
                            ? null
                            : BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: c.borderSubtle,
                                  ),
                                ),
                              ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: PostinoSpacing.s0_5,
                          children: [
                            if (s.title case final t? when !collapsed)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  PostinoSpacing.s3,
                                  PostinoSpacing.s2,
                                  PostinoSpacing.s3,
                                  PostinoSpacing.s1,
                                ),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    t.toUpperCase(),
                                    style: PostinoText.overline.copyWith(
                                      color: c.inkSubtle,
                                    ),
                                  ),
                                ),
                              ),
                            for (final item in s.items)
                              PostinoDrawerItemTile(
                                item,
                                collapsed: collapsed,
                                key: _itemKeys.putIfAbsent(n++, GlobalKey.new),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
