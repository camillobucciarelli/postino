import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_avatar.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A Conversazione in the list (Comfortable): its latest message, and the thread [count] from 2.
/// With [account] (Posta unificata) it carries the Account's bar and the badge on the avatar;
/// inside one Account the AppBar already says where you are. [selected]: open in the detail pane.
class PostinoMessageTile extends StatelessWidget {
  const PostinoMessageTile({
    super.key,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.time,
    required this.unread,
    required this.starred,
    required this.semanticLabel,
    this.account,
    this.count = 1,
    this.selected = false,
    this.onTap,
    this.focusNode,
  });

  final String sender;
  final String subject;
  final String preview;

  /// Already formatted (“09:42”, “Ieri”, “lun”, “12 mar”).
  final String time;
  final bool unread;
  final bool starred;

  /// The whole row read out as one node: state, sender, subject, Stella, Account, time.
  final String semanticLabel;
  final PostinoAccountRef? account;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  /// The row's focus, owned by the list so it can move it with the keyboard.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final d = context.density;
    // At large text sizes the time moves under the sender and the subject may wrap.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final large = scale > 1.5;
    // Enlarged text wraps instead of being cut: no line limit, no ellipsis.
    final wrap = scale > 1;
    final fg = unread ? c.listItemFgUnread : c.listItemFgRead;
    final timeText = Text(
      time,
      style: unread
          ? PostinoText.metaStrong.copyWith(color: c.brand)
          : PostinoText.meta.copyWith(color: c.listItemMeta),
    );
    final a = account;
    return Semantics(
      container: true,
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.listItemBgSelected : c.listItemBg,
        child: InkWell(
          focusNode: focusNode,
          onTap: onTap,
          child: PostinoFocusRing(
            inset: true,
            child: Container(
              constraints: BoxConstraints(minHeight: d.rowHeight),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: c.listItemDivider,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  if (a != null)
                    Positioned(
                      key: const ValueKey('account-bar'),
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: PostinoBorder.accountBarWidth,
                      child: ColoredBox(color: c.account(a.color).color),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: PostinoSpacing.s4,
                      vertical: d.padY,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: d.gap,
                      children: [
                        PostinoAvatar(
                          name: sender,
                          size: d.avatar,
                          badge: a == null
                              ? null
                              : PostinoAccountMark(
                                  color: a.color,
                                  initial: a.initial,
                                  size: PostinoSize.accountBadge,
                                ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                spacing: PostinoSpacing.s2,
                                children: [
                                  if (unread)
                                    Container(
                                      key: const ValueKey('unread'),
                                      width: PostinoSpacing.s2,
                                      height: PostinoSpacing.s2,
                                      decoration: BoxDecoration(
                                        color: c.unread,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      sender,
                                      maxLines: wrap ? null : 1,
                                      overflow: wrap
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      style:
                                          (unread
                                                  ? PostinoText.sender
                                                  : PostinoText.senderRead)
                                              .copyWith(color: fg),
                                    ),
                                  ),
                                  if (count > 1)
                                    Container(
                                      key: const ValueKey('count'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: PostinoSpacing.s1,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: c.borderSubtle,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          PostinoRadius.xs,
                                        ),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: PostinoText.meta.copyWith(
                                          color: c.listItemMeta,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (!large) timeText,
                                ],
                              ),
                              if (large) timeText,
                              Row(
                                spacing: PostinoSpacing.s1,
                                children: [
                                  Expanded(
                                    child: Text(
                                      subject,
                                      maxLines: wrap ? null : 1,
                                      overflow: wrap
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      style:
                                          (unread
                                                  ? PostinoText.subject
                                                  : PostinoText.subjectRead)
                                              .copyWith(color: fg),
                                    ),
                                  ),
                                  if (starred)
                                    PostinoIcon(
                                      PostinoIcons.star,
                                      size: PostinoSize.iconSm,
                                      color: c.star,
                                      filled: true,
                                    ),
                                ],
                              ),
                              if (d.previewLines > 0)
                                Text(
                                  preview,
                                  maxLines: wrap ? null : d.previewLines,
                                  overflow: wrap
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: PostinoText.preview.copyWith(
                                    color: c.listItemFgRead,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
