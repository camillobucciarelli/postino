// PROTOTIPO (#106) — modifica proposta a molecules/postino_banner.dart: uno slot `progress`
// sotto il messaggio (e `leading` per sostituire l'icona con uno spinner). Copia ridotta
// (senza Account) per non toccare lib/.
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_button.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/molecules/postino_banner.dart' show PostinoBannerTone;
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// PostinoBanner with a [progress] slot (a PostinoProgressBar) under the message and an optional
/// [leading] in place of the tone's icon. A live region like the original: keep what changes at every
/// tick out of its semantics (the bar's stepped value speaks instead).
class const PostinoProgressBanner({
  super.key,
  required final PostinoBannerTone tone,
  required final String title,
  final String? message,
  final Widget? leading,
  final PostinoIconData? icon,
  final Widget? progress,
  final String? actionLabel,
  final VoidCallback? onAction,
  final String? secondaryActionLabel,
  final VoidCallback? onSecondaryAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    Widget button(String label, VoidCallback? onPressed) => TextButtonTheme(
      data: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.ink)),
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
    final under = large || actions.length > 1 || progress != null;
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
              PostinoBannerTone.info => c.brandSubtle,
              PostinoBannerTone.offline => c.surfacePressed,
            },
            borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.md)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: PostinoSpacing.s3,
            children: [
              SizedBox.square(
                dimension: PostinoSize.iconLg,
                child: Center(
                  child:
                      leading ??
                      PostinoIcon(
                        icon ?? PostinoIcons.alert,
                        size: PostinoSize.iconLg,
                        color: switch (tone) {
                          PostinoBannerTone.danger => c.danger,
                          PostinoBannerTone.warning => c.warning,
                          PostinoBannerTone.info => c.brand,
                          PostinoBannerTone.offline => c.inkMuted,
                        },
                      ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: PostinoSpacing.s0_5, right: PostinoSpacing.s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PostinoSpacing.s1,
                    children: [
                      Text(title, style: PostinoText.subject.copyWith(color: c.ink)),
                      if (message case final m?) Text(m, style: PostinoText.preview.copyWith(color: c.ink)),
                      if (progress case final p?)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: PostinoSpacing.s1),
                          child: p,
                        ),
                      if (under && actions.isNotEmpty)
                        Transform.translate(
                          offset: const Offset(-PostinoSpacing.s3, 0),
                          child: Wrap(spacing: PostinoSpacing.s3, runSpacing: PostinoSpacing.s1, children: actions),
                        ),
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
