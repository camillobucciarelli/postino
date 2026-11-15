// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_fade_switcher.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_drawer_item.dart';
import 'postino_sync_status.dart';

/// One row of `PostinoNavigationDrawer` (not in the barrel): [item] as a row, or, [collapsed], as a rail icon.
/// The unread dot and the Da ricollegare badge fade in and out (#283, `duration-toggle`). A group ([PostinoDrawerItem.children])
/// is a button that says whether it is expanded and ends with a chevron; closed, it shows its children's unread dot and
/// is the selected one when it hides the active child.
class const PostinoDrawerItemTile(
  /// The destination it shows and opens.
  final PostinoDrawerItem item, {

  /// Icon sidebar: only the icon or mark, a dot for unread, the name in a tooltip and the semantics.
  required final bool collapsed,
  super.key,
}) extends StatelessWidget {
  /// Crea la riga per `item`; `collapsed` la riduce all'icona.
  this;

  bool get _closed => item.children != null && !item.expanded;

  /// The dot's name: the item's own, or, closed, that of an unread child.
  String? get _unread =>
      item.unreadLabel ?? (_closed ? item.children!.map((i) => i.unreadLabel).nonNulls.firstOrNull : null);

  Widget _chevron(BuildContext context, double size) => AnimatedRotation(
    turns: item.expanded ? .5 : 0,
    duration: PostinoMotion.of(context, PostinoMotion.threadExpand),
    curve: PostinoMotion.standard,
    child: PostinoIcon(PostinoIcons.chevronDown, size: size, color: context.pc.inkMuted),
  );

  Widget _railIcon(BuildContext context, PostinoColors c) {
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
          Positioned(
            top: PostinoSpacing.s1 + 2,
            right: PostinoSpacing.s1 + 2,
            child: _FadeToggle(_unread == null ? null : const _UnreadDot()),
          ),
          if (item.children != null)
            Positioned(
              bottom: PostinoSpacing.s1,
              left: PostinoSpacing.s1,
              child: _chevron(context, PostinoSize.iconSm - 2),
            ),
          Positioned(
            bottom: PostinoSpacing.s1,
            right: PostinoSpacing.s1,
            child: _FadeToggle(
              item.reconnectLabel == null
                  ? null
                  : ExcludeSemantics(
                      // A shape, not only a color; the ground keeps it apart from the mark.
                      child: Container(
                        key: const ValueKey('reconnect-badge'),
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(color: c.drawerBg, shape: BoxShape.circle),
                        child: PostinoIcon(PostinoIcons.alert, size: PostinoSize.iconSm - 2, color: c.warning),
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
    final group = item.children;
    final unread = _unread;
    final name = [item.semanticLabel ?? item.label, item.reconnectLabel, unread].nonNulls.join(', ');
    // A group is one button that says its state (like PostinoMessageRecipients); Enter/Space through the InkWell.
    return Semantics(
      selected: item.active || (_closed && group!.any((i) => i.active)),
      button: collapsed || group != null ? true : null,
      expanded: group == null ? null : item.expanded,
      label: collapsed || group != null ? name : null,
      onTap: group == null ? null : item.onTap,
      excludeSemantics: group != null,
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
            // Opening or closing a group stays in the drawer.
            if (group == null) Scaffold.maybeOf(context)?.closeDrawer();
            item.onTap();
          },
          // The ring, not the fill, shows focus on the active item, whose box has the same color.
          child: PostinoFocusRing(
            // A rail icon is a control with a shape of its own; a row spans the width.
            inset: !collapsed,
            borderRadius: radius,
            child: collapsed
                ? Tooltip(message: item.label, excludeFromSemantics: true, child: _railIcon(context, c))
                : Container(
                    constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
                    padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3),
                    child: Row(
                      children: [
                        if (a != null)
                          PostinoAccountMark(color: a.color, initial: a.initial, size: 22)
                        else
                          PostinoIcon(
                            item.icon ?? PostinoIcons.tag,
                            size: PostinoSize.iconLg,
                            color: item.active ? c.drawerItemIconActive : c.drawerItemIcon,
                          ),
                        const SizedBox(width: PostinoSpacing.s3),
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
                        // Each with the gap before it, so an absent one takes no room.
                        _FadeToggle(
                          unread == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsetsDirectional.only(start: PostinoSpacing.s3),
                                  child: _UnreadDot(label: unread),
                                ),
                        ),
                        _FadeToggle(
                          item.reconnectLabel == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsetsDirectional.only(start: PostinoSpacing.s3),
                                  child: PostinoSyncStatus(
                                    state: PostinoSyncState.reconnect,
                                    label: item.reconnectLabel!,
                                    compact: true,
                                  ),
                                ),
                        ),
                        if (group != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: PostinoSpacing.s3),
                            child: _chevron(context, PostinoSize.iconSm),
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

/// The unread dot (8 px, `unread`): in the icon sidebar the item's semantics already say it,
/// in the extended one it reads [label] itself.
class const _UnreadDot({final String? label}) extends StatelessWidget {
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

/// [child] fading in when it comes and out when it goes (`duration-toggle`); null: nothing, no room.
class const _FadeToggle(final Widget? child) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      PostinoFadeSwitcher(duration: PostinoMotion.toggle, child: child ?? const SizedBox.shrink());
}
