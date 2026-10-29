import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_avatar.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A message in the list (Comfortable). With [account] (Posta unificata) it carries the Account's
/// bar and the badge on the avatar; inside one Account the AppBar already says where you are.
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

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final d = context.density;
    // At large text sizes the time moves under the sender and the subject may wrap.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.5;
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
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: d.rowHeight),
        decoration: BoxDecoration(
          color: c.listItemBg,
          border: Border(
            bottom: BorderSide(
              color: c.listItemDivider,
              width: PostinoBorder.borderWidthHairline,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    (unread
                                            ? PostinoText.sender
                                            : PostinoText.senderRead)
                                        .copyWith(color: fg),
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
                                maxLines: large ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
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
                            maxLines: d.previewLines,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}
