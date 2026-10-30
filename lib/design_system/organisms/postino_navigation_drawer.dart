import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../atoms/postino_icon_button.dart';
import '../molecules/postino_sync_status.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

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

/// A destination of the drawer: an [icon] or an [account] mark, and, for an Account Da ricollegare,
/// the compact SyncStatus named [reconnectLabel]. [unreadLabel] ("Non letto") is set when it holds unread mail:
/// the icon sidebar shows it as a dot and reads it out.
class PostinoDrawerItem {
  const PostinoDrawerItem({
    required this.label,
    required this.onTap,
    this.key,
    this.active = false,
    this.icon,
    this.account,
    this.reconnectLabel,
    this.unreadLabel,
  });

  final String label;
  final VoidCallback onTap;
  final Key? key;
  final bool active;
  final PostinoIconData? icon;
  final PostinoAccountRef? account;
  final String? reconnectLabel;
  final String? unreadLabel;
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
                                    width: PostinoBorder.borderWidthHairline,
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
                              _DrawerItem(
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(this.item, {required this.collapsed, super.key});
  final PostinoDrawerItem item;

  /// Icon sidebar: only the icon or mark, a dot for unread, the name in a tooltip and the semantics.
  final bool collapsed;

  Widget _railIcon(PostinoColors c) {
    final a = item.account;
    return SizedBox.square(
      dimension: PostinoSize.touchTargetAndroid,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (a != null)
            PostinoAccountMark(color: a.color, initial: a.initial)
          else
            PostinoIcon(
              item.icon ?? PostinoIcons.tag,
              size: PostinoSize.iconLg,
              color: item.active ? c.drawerItemIconActive : c.drawerItemIcon,
            ),
          if (item.unreadLabel != null)
            Positioned(
              top: PostinoSpacing.s1 + 2,
              right: PostinoSpacing.s1 + 2,
              child: ExcludeSemantics(
                child: Container(
                  key: const ValueKey('unread-dot'),
                  width: PostinoSpacing.s2,
                  height: PostinoSpacing.s2,
                  decoration: BoxDecoration(
                    color: c.unread,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final a = item.account;
    const radius = BorderRadius.all(Radius.circular(PostinoRadius.sm));
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
    final name = [
      item.label,
      item.reconnectLabel,
      item.unreadLabel,
    ].nonNulls.join(', ');
    return Semantics(
      selected: item.active,
      button: collapsed ? true : null,
      label: collapsed ? name : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          key: item.key,
          borderRadius: radius,
          // Only the sliding box marks the active item: no hover/press/splash pill of our own.
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused)
                ? c.drawerItemBgActive
                : Colors.transparent,
          ),
          onTap: () {
            Scaffold.maybeOf(context)?.closeDrawer();
            item.onTap();
          },
          // The ring, not the fill, shows focus on the active item, whose box has the same color.
          child: PostinoFocusRing(
            // A rail icon is a control with a shape of its own; a row spans the width.
            inset: !collapsed,
            borderRadius: radius,
            child: collapsed
                ? Tooltip(
                    message: item.label,
                    excludeFromSemantics: true,
                    child: _railIcon(c),
                  )
                : Container(
                    constraints: const BoxConstraints(
                      minHeight: PostinoSize.touchTargetAndroid,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: PostinoSpacing.s3,
                    ),
                    child: Row(
                      spacing: PostinoSpacing.s3,
                      children: [
                        if (a != null)
                          PostinoAccountMark(
                            color: a.color,
                            initial: a.initial,
                            size: 22,
                          )
                        else
                          PostinoIcon(
                            item.icon ?? PostinoIcons.tag,
                            size: PostinoSize.iconLg,
                            color: item.active
                                ? c.drawerItemIconActive
                                : c.drawerItemIcon,
                          ),
                        Expanded(
                          child: Text(
                            item.label,
                            // Enlarged text wraps instead of being cut.
                            maxLines: wrap ? null : 1,
                            overflow: wrap
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: PostinoText.label.copyWith(
                              color: c.drawerItemFg,
                              fontWeight: item.active ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (item.reconnectLabel case final l?)
                          PostinoSyncStatus(
                            state: PostinoSyncState.reconnect,
                            label: l,
                            compact: true,
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
