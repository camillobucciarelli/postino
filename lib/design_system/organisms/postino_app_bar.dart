import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_icon_button.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The bar on top of a list: `menu` opening the drawer, title and a `meta` subtitle saying where you are.
/// Inside one Account its mark sits next to the title.
class PostinoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PostinoAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.account,
  });

  final String title;
  final String? subtitle;
  final PostinoAccountRef? account;

  @override
  Size get preferredSize => const Size.fromHeight(PostinoSize.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final a = account;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: Builder(
        builder: (context) => PostinoIconButton(
          icon: PostinoIcons.menu,
          label: MaterialLocalizations.of(context).openAppDrawerTooltip,
          onPressed: Scaffold.of(context).hasDrawer
              ? Scaffold.of(context).openDrawer
              : null,
        ),
      ),
      titleSpacing: PostinoSpacing.s1,
      // ponytail: the compact bar is 56 tall, so its text stops growing at 130%; a growing bar when 200% needs it.
      title: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              spacing: PostinoSpacing.s2,
              children: [
                if (a != null)
                  PostinoAccountMark(
                    color: a.color,
                    initial: a.initial,
                    size: 22,
                  ),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PostinoText.appBarTitle.copyWith(color: c.ink),
                  ),
                ),
              ],
            ),
            if (subtitle case final s?)
              Text(
                s,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PostinoText.meta.copyWith(color: c.inkSubtle),
              ),
          ],
        ),
      ),
    );
  }
}
