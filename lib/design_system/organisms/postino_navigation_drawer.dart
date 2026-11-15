// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_icon_button.dart';
import '../atoms/postino_reveal.dart';
import '../molecules/postino_drawer_item.dart';
import '../molecules/postino_drawer_item_tile.dart';
import '../molecules/postino_drawer_section_header.dart';
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

/// Una sezione del drawer, con un titolo facoltativo e le sue voci. Con [onToggle] è collassabile: l'intestazione
/// diventa un pulsante che la apre e la chiude.
class const PostinoDrawerSection({
  /// Intestazione della sezione, mostrata in maiuscolo; nascosta quando la barra è ridotta, se non è collassabile.
  final String? title,

  /// Voci della sezione, in ordine.
  required final List<PostinoDrawerItem> items,

  /// Account di cui l'intestazione collassabile mostra il segno.
  final PostinoAccountRef? account,

  /// Se la sezione collassabile è aperta.
  final bool expanded = true,

  /// Apre o chiude la sezione; se impostata (con [title]) la sezione è collassabile.
  final VoidCallback? onToggle,
}) {
  /// Crea una sezione con le sue voci; senza titolo non mostra l'intestazione.
  this;
}

/// Mailboxes and Etichette: a modal drawer from the left (tapping an item closes it), or the docked sidebar,
/// which (see [PostinoSidebarScope]) has a button to open and close it and, collapsed, shows only icons.
/// The highlight of the active item is one box under the list that slides to the new item.
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

  /// By (section, item) for an item, by section for a collapsible header: a section's keys stay its own while it
  /// closes, whatever the other sections do.
  final _keys = <Object, GlobalKey>{};
  Rect? _active;
  var _slide = false;

  GlobalKey _key(Object id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// [key] is what shows the active item: the item, or the header of its closed section; null: none.
  void _measure(GlobalKey? key) {
    if (!mounted) return;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    // An item that left the tree (its section closed) has no context.
    final item = key?.currentContext?.findRenderObject() as RenderBox?;
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
    bool closed(PostinoDrawerSection s) => s.onToggle != null && s.title != null && !s.expanded;
    GlobalKey? activeKey;
    for (final (si, s) in sections.indexed) {
      for (final (ii, item) in s.items.indexed) {
        if (item.active) activeKey = closed(s) ? _key(si) : _key((si, ii));
      }
    }
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
                Column(
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
                            if (s.onToggle case final toggle? when s.title != null) ...[
                              PostinoDrawerSectionHeader(
                                key: _key(i),
                                title: s.title!,
                                account: s.account,
                                expanded: s.expanded,
                                collapsed: collapsed,
                                selected: closed(s) && s.items.any((item) => item.active),
                                unreadLabel: s.expanded
                                    ? null
                                    : s.items.map((item) => item.unreadLabel).nonNulls.firstOrNull,
                                onToggle: toggle,
                              ),
                              // Closed, the items leave: no taps, no Tab, nothing read (PostinoSizeFade).
                              PostinoReveal(
                                duration: PostinoMotion.threadExpand,
                                child: s.expanded
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        spacing: PostinoSpacing.s0_5,
                                        children: [
                                          for (final (ii, item) in s.items.indexed)
                                            PostinoDrawerItemTile(item, collapsed: collapsed, key: _key((i, ii))),
                                        ],
                                      )
                                    : null,
                              ),
                            ] else ...[
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
                              for (final (ii, item) in s.items.indexed)
                                PostinoDrawerItemTile(item, collapsed: collapsed, key: _key((i, ii))),
                            ],
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
