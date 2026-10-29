import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_button.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

enum PostinoBannerTone { danger, warning, offline, neutral }

/// A lasting problem at the top of the list, or a notice above a message: [title] says what happens,
/// [message] why or what to do, up to two actions (two sit under the text). With [account] its mark sits in the title.
class PostinoBanner extends StatelessWidget {
  const PostinoBanner({
    super.key,
    required this.tone,
    required this.title,
    this.icon,
    this.message,
    this.account,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final PostinoBannerTone tone;
  final String title;

  /// Defaults to `alert`, or `cloud-off` when offline.
  final PostinoIconData? icon;
  final String? message;
  final PostinoAccountRef? account;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final a = account;
    // At large text sizes the action moves under the text, or the title has no room.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    // The design's banner action: a ghost button in ink, underlined.
    Widget button(String label, VoidCallback? onPressed) => TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.ink),
      ),
      child: PostinoButton(
        label: label,
        onPressed: onPressed,
        variant: PostinoButtonVariant.ghost,
        size: PostinoButtonSize.sm,
        underline: true,
      ),
    );
    final actions = [
      if (actionLabel case final l?) button(l, onAction),
      if (secondaryActionLabel case final l?) button(l, onSecondaryAction),
    ];
    final under = large || actions.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: PostinoSpacing.s2),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            PostinoSpacing.s4,
            PostinoSpacing.s3,
            PostinoSpacing.s2,
            PostinoSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: switch (tone) {
              PostinoBannerTone.danger => c.dangerSubtle,
              PostinoBannerTone.warning => c.warningSubtle,
              PostinoBannerTone.offline ||
              PostinoBannerTone.neutral => c.surfacePressed,
            },
            borderRadius: const BorderRadius.all(
              Radius.circular(PostinoRadius.md),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: PostinoSpacing.s3,
            children: [
              PostinoIcon(
                icon ??
                    (tone == PostinoBannerTone.offline
                        ? PostinoIcons.cloudOff
                        : PostinoIcons.alert),
                size: PostinoSize.iconLg,
                color: c.ink,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: PostinoSpacing.s0_5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PostinoSpacing.s0_5,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            if (a != null) ...[
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: PostinoAccountMark(
                                  color: a.color,
                                  initial: a.initial,
                                  size: PostinoSize.accountBadge,
                                ),
                              ),
                              const TextSpan(text: ' '),
                            ],
                            TextSpan(text: title),
                          ],
                        ),
                        style: PostinoText.subject.copyWith(color: c.ink),
                      ),
                      if (message case final m?)
                        Text(
                          m,
                          style: PostinoText.preview.copyWith(color: c.ink),
                        ),
                      if (under && actions.isNotEmpty)
                        Wrap(spacing: PostinoSpacing.s2, children: actions),
                    ],
                  ),
                ),
              ),
              if (!under) ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
