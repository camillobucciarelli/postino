import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_avatar.dart';
import '../atoms/postino_button.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A Conversazione: [subject] in `title`, the Account that received it, then its [messages]
/// (oldest first, [PostinoThreadMessage]); at most `reading-max-width` wide.
class PostinoThreadView extends StatelessWidget {
  const PostinoThreadView({
    super.key,
    required this.subject,
    required this.account,
    required this.accountName,
    required this.messages,
  });

  final String subject;
  final PostinoAccountRef account;
  final String accountName;
  final List<Widget> messages;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: PostinoSize.readingMaxWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.only(bottom: PostinoSpacing.s8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PostinoSpacing.s4,
                PostinoSpacing.s2,
                PostinoSpacing.s4,
                PostinoSpacing.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: PostinoSpacing.s2,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      subject,
                      style: PostinoText.title.copyWith(color: c.ink),
                    ),
                  ),
                  Row(
                    spacing: PostinoSpacing.s2,
                    children: [
                      PostinoAccountMark(
                        color: account.color,
                        initial: account.initial,
                        size: PostinoSize.accountBadge,
                      ),
                      Flexible(
                        child: Text(
                          accountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PostinoText.meta.copyWith(color: c.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ...messages,
          ],
        ),
      ),
    );
  }
}

/// One message of a Conversazione. Collapsed: avatar 32, sender, one line of [preview], time.
/// Expanded: avatar 40, sender, [recipients], time, then [body]. A tap on the header toggles,
/// in `duration-thread-expand` with `easing-emphasized-decelerate`.
class PostinoThreadMessage extends StatelessWidget {
  const PostinoThreadMessage({
    super.key,
    required this.sender,
    required this.time,
    required this.preview,
    required this.expanded,
    required this.onToggle,
    required this.body,
    this.recipients,
    this.unread = false,
  });

  final String sender;

  /// Already formatted, like the list's.
  final String time;
  final String preview;
  final bool expanded;
  final VoidCallback onToggle;

  /// Shown only when expanded: a [PostinoMessageBody].
  final Widget body;

  /// “a me@example.com”, under the sender when expanded.
  final String? recipients;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final avatar = expanded ? PostinoSize.avatarMd : 32.0;
    final header = InkWell(
      onTap: onToggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PostinoSpacing.s12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PostinoSpacing.s4,
            vertical: PostinoSpacing.s2,
          ),
          child: Row(
            spacing: PostinoSpacing.s3,
            children: [
              PostinoAvatar(name: sender, size: avatar),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (unread || expanded
                                  ? PostinoText.sender
                                  : PostinoText.senderRead)
                              .copyWith(color: c.ink),
                    ),
                    if (expanded ? recipients : preview case final s?)
                      Text(
                        s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (expanded ? PostinoText.meta : PostinoText.preview)
                                .copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
              ),
              Text(time, style: PostinoText.meta.copyWith(color: c.inkSubtle)),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      expanded: expanded,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: c.borderSubtle,
              width: PostinoBorder.borderWidthHairline,
            ),
          ),
        ),
        child: AnimatedSize(
          duration: PostinoMotion.of(context, PostinoMotion.threadExpand),
          curve: PostinoMotion.emphasizedDecelerate,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PostinoSpacing.s4,
                    PostinoSpacing.s1,
                    PostinoSpacing.s4,
                    PostinoSpacing.s6,
                  ),
                  child: body,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The body of an expanded message: its [text] in `body`, selectable;
/// or, while it is not there, a quiet note and maybe a retry.
class PostinoMessageBody extends StatelessWidget {
  const PostinoMessageBody({super.key, required String this.text})
    : note = null,
      actionLabel = null,
      onAction = null;

  /// No body yet: [note] says why (“Caricamento…”, “Corpo non disponibile offline”), [actionLabel] retries.
  const PostinoMessageBody.missing({
    super.key,
    required String this.note,
    this.actionLabel,
    this.onAction,
  }) : text = null;

  final String? text;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    if (text case final t?) {
      return SelectableText(t, style: PostinoText.body.copyWith(color: c.ink));
    }
    final label = actionLabel;
    return Row(
      spacing: PostinoSpacing.s2,
      children: [
        Flexible(
          child: Text(
            note!,
            style: PostinoText.preview.copyWith(color: c.inkMuted),
          ),
        ),
        if (label != null)
          PostinoButton(
            label: label,
            onPressed: onAction,
            variant: PostinoButtonVariant.ghost,
            size: PostinoButtonSize.sm,
          ),
      ],
    );
  }
}
