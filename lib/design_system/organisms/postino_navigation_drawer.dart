import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_icon.dart';
import '../molecules/postino_sync_status.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A destination of the drawer: an [icon] or an [account] mark, and, for an Account Da ricollegare,
/// the compact SyncStatus named [reconnectLabel].
class PostinoDrawerItem {
  const PostinoDrawerItem({
    required this.label,
    required this.onTap,
    this.key,
    this.active = false,
    this.icon,
    this.account,
    this.reconnectLabel,
  });

  final String label;
  final VoidCallback onTap;
  final Key? key;
  final bool active;
  final PostinoIconData? icon;
  final PostinoAccountRef? account;
  final String? reconnectLabel;
}

class PostinoDrawerSection {
  const PostinoDrawerSection({this.title, required this.items});
  final String? title;
  final List<PostinoDrawerItem> items;
}

/// Mailboxes and Etichette, as a modal drawer from the left; tapping an item closes it.
class PostinoNavigationDrawer extends StatelessWidget {
  const PostinoNavigationDrawer({super.key, required this.sections});

  final List<PostinoDrawerSection> sections;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Drawer(
      width: PostinoSize.drawerWidth,
      backgroundColor: c.drawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(PostinoRadius.lg),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PostinoSpacing.s3),
          children: [
            for (final (i, s) in sections.indexed)
              Container(
                margin: EdgeInsets.only(top: i == 0 ? 0 : PostinoSpacing.s2),
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
                    if (s.title case final t?)
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
                    for (final item in s.items) _DrawerItem(item),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(this.item);
  final PostinoDrawerItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final a = item.account;
    const radius = BorderRadius.all(Radius.circular(PostinoRadius.sm));
    return Semantics(
      selected: item.active,
      child: Material(
        color: item.active ? c.drawerItemBgActive : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          key: item.key,
          borderRadius: radius,
          onTap: () {
            Scaffold.maybeOf(context)?.closeDrawer();
            item.onTap();
          },
          child: Container(
            constraints: const BoxConstraints(
              minHeight: PostinoSize.touchTargetAndroid,
            ),
            padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    );
  }
}
