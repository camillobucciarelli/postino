// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_icon_button.dart';
import '../atoms/postino_reveal.dart';
import '../molecules/postino_drawer_item.dart';
import '../molecules/postino_drawer_item_tile.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

// The destination type stays where consumers of the drawer find it.
export '../molecules/postino_drawer_item.dart' show PostinoDrawerItem;

/// What the drawer docked by `PostinoSidebarShell` knows: whether it shows icons only,
/// and the button that opens or closes it (named [toggleLabel], what it will do).
class const PostinoSidebarScope({
  super.key,

  /// Vero quando la barra mostra solo le icone.
  required final bool collapsed,

  /// Nome accessibile del pulsante che apre o chiude la barra.
  required final String toggleLabel,

  /// Apre o chiude la barra laterale.
  required final VoidCallback toggle,
  required super.child,
}) extends InheritedWidget {
  /// Espone a drawer e pulsanti lo stato della barra laterale, da un antenato nell'albero dei widget.
  this;

  /// Null for a modal drawer: always extended, no button.
  static PostinoSidebarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PostinoSidebarScope>();

  @override
  bool updateShouldNotify(PostinoSidebarScope old) => collapsed != old.collapsed || toggleLabel != old.toggleLabel;
}

/// Una sezione del drawer, con un titolo facoltativo e le sue voci.
class const PostinoDrawerSection({
  /// Intestazione della sezione, mostrata in maiuscolo; nascosta quando la barra è ridotta.
  final String? title,

  /// Voci della sezione, in ordine.
  required final List<PostinoDrawerItem> items,
}) {
  /// Crea una sezione con le sue voci; senza titolo non mostra l'intestazione.
  this;
}

/// Mailboxes and Etichette: a modal drawer from the left (tapping an item closes it), or the docked sidebar,
/// which (see [PostinoSidebarScope]) has a button to open and close it and, collapsed, shows only icons.
/// The highlight of the active item is one box under the list that slides to the new item, or to its group while
/// that is closed. A group's children open and close with [PostinoReveal] (#311).
class const PostinoNavigationDrawer({
  super.key,

  /// Le sezioni da mostrare, dall'alto in basso.
  required final List<PostinoDrawerSection> sections,
}) extends StatefulWidget {
  /// Crea il drawer con le sezioni indicate.
  this;

  @override
  State<PostinoNavigationDrawer> createState() => _PostinoNavigationDrawerState();
}

class _PostinoNavigationDrawerState() extends State<PostinoNavigationDrawer> {
  final _stack = GlobalKey();

  /// By the item's key, else by position, (section, item) or (section, item, child): a focused Etichetta stays itself
  /// when a sync adds another before it, and a closing group keeps its keys.
  final _keys = <Object, GlobalKey>{};
  Rect? _active;
  var _slide = false;
  GlobalKey? _activeKey;
  GlobalKey? _measuredKey;

  GlobalKey _key(Object id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// [key] shows the active item: the item, or its group while closed; null: none. The box slides to a new key, and
  /// follows at once the same one when a group opening or closing above it moves it.
  void _measure(GlobalKey? key) {
    if (!mounted) return;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    // A child of a closed group left the tree: no context.
    final item = key?.currentContext?.findRenderObject() as RenderBox?;
    final rect = stack == null || item == null || !item.attached
        ? null
        : item.localToGlobal(Offset.zero, ancestor: stack) & item.size;
    if (rect == _active) return;
    // The first position (or one after no active item) is placed, not slid to.
    setState(() {
      _slide = key != _measuredKey && _active != null && rect != null;
      _measuredKey = key;
      _active = rect;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final sections = widget.sections;
    final scope = PostinoSidebarScope.maybeOf(context);
    final collapsed = scope?.collapsed ?? false;
    GlobalKey? activeKey;
    for (final (si, s) in sections.indexed) {
      for (final (ii, item) in s.items.indexed) {
        if (item.active) activeKey = _key(item.key ?? (si, ii));
        for (final (ci, child) in (item.children ?? const <PostinoDrawerItem>[]).indexed) {
          if (child.active) activeKey = item.expanded ? _key(child.key ?? (si, ii, ci)) : _key(item.key ?? (si, ii));
        }
      }
    }
    _activeKey = activeKey;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(activeKey));
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
                    duration: PostinoMotion.of(context, _slide ? PostinoMotion.menuIndicator : Duration.zero),
                    curve: PostinoMotion.emphasized,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.drawerItemBgActive,
                        borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm)),
                      ),
                    ),
                  ),
                // A group opening or closing moves the rows below it frame by frame: the box follows them.
                NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(_activeKey));
                    return true;
                  },
                  child: Column(
                    children: [
                      for (final (i, s) in sections.indexed)
                        Container(
                          margin: EdgeInsets.only(top: i == 0 ? 0 : PostinoSpacing.s2),
                          padding: const EdgeInsets.only(top: PostinoSpacing.s2),
                          decoration: i == 0
                              ? null
                              : BoxDecoration(
                                  border: Border(top: BorderSide(color: c.borderSubtle)),
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
                                      style: PostinoText.overline.copyWith(color: c.inkSubtle),
                                    ),
                                  ),
                                ),
                              for (final (ii, item) in s.items.indexed) ...[
                                PostinoDrawerItemTile(item, collapsed: collapsed, key: _key(item.key ?? (i, ii))),
                                if (item.children case final children?)
                                  // Closed, the children leave: no taps, no Tab, nothing read (PostinoSizeFade).
                                  SizeChangedLayoutNotifier(
                                    child: PostinoReveal(
                                      duration: PostinoMotion.threadExpand,
                                      child: item.expanded
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              spacing: PostinoSpacing.s0_5,
                                              children: [
                                                for (final (ci, child) in children.indexed)
                                                  PostinoDrawerItemTile(
                                                    child,
                                                    collapsed: collapsed,
                                                    key: _key(child.key ?? (i, ii, ci)),
                                                  ),
                                              ],
                                            )
                                          : null,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
