import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_drawer_item.dart';
import 'postino_sync_status.dart';

/// One row of `PostinoNavigationDrawer` (not in the barrel): [item] as a row, or, [collapsed], as a rail icon.
class PostinoDrawerItemTile extends StatelessWidget {
  /// Crea la riga per `item`; `collapsed` la riduce all'icona.
  const PostinoDrawerItemTile(this.item, {required this.collapsed, super.key});

  /// The destination it shows and opens.
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
            const Positioned(top: PostinoSpacing.s1 + 2, right: PostinoSpacing.s1 + 2, child: _UnreadDot()),
          if (item.reconnectLabel != null)
            Positioned(
              bottom: PostinoSpacing.s1,
              right: PostinoSpacing.s1,
              child: ExcludeSemantics(
                // A shape, not only a color; the ground keeps it apart from the mark.
                child: Container(
                  key: const ValueKey('reconnect-badge'),
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(color: c.drawerBg, shape: BoxShape.circle),
                  child: PostinoIcon(PostinoIcons.alert, size: PostinoSize.iconSm - 2, color: c.warning),
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
    final name = [item.label, item.reconnectLabel, item.unreadLabel].nonNulls.join(', ');
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
            (s) => s.contains(WidgetState.focused) ? c.drawerItemBgActive : Colors.transparent,
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
                ? Tooltip(message: item.label, excludeFromSemantics: true, child: _railIcon(c))
                : Container(
                    constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
                    padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3),
                    child: Row(
                      spacing: PostinoSpacing.s3,
                      children: [
                        if (a != null)
                          PostinoAccountMark(color: a.color, initial: a.initial, size: 22)
                        else
                          PostinoIcon(
                            item.icon ?? PostinoIcons.tag,
                            size: PostinoSize.iconLg,
                            color: item.active ? c.drawerItemIconActive : c.drawerItemIcon,
                          ),
                        Expanded(
                          child: Text(
                            item.label,
                            // Enlarged text wraps instead of being cut.
                            maxLines: wrap ? null : 1,
                            overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: PostinoText.label.copyWith(
                              color: c.drawerItemFg,
                              fontWeight: item.active ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (item.unreadLabel case final l?) _UnreadDot(label: l),
                        if (item.reconnectLabel case final l?)
                          PostinoSyncStatus(state: PostinoSyncState.reconnect, label: l, compact: true),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The unread dot (8 px, `unread`): in the icon sidebar the item's semantics already say it,
/// in the extended one it reads [label] itself.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      key: const ValueKey('unread-dot'),
      width: PostinoSpacing.s2,
      height: PostinoSpacing.s2,
      decoration: BoxDecoration(color: context.pc.unread, shape: BoxShape.circle),
    );
    return label == null ? ExcludeSemantics(child: dot) : Semantics(label: label, child: dot);
  }
}
