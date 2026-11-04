import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_button.dart';
import '../atoms/postino_icon.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Gravità di un `PostinoBanner`: ne determina colori e icona.
enum PostinoBannerTone() {
  /// Errore da correggere.
  danger,

  /// Attenzione, qualcosa non va del tutto.
  warning,

  /// Informazione neutra.
  info,

  /// Mancanza di rete.
  offline,
}

/// A lasting problem at the top of the list, or a notice above a message: [title] says what happens,
/// [message] why or what to do, up to two actions (two sit under the text, wrapping). With [account] its mark sits in the title.
/// [spaced] adds the gap under it, for a list of banners; off inside a message, whose own layout spaces it.
class const PostinoBanner({
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
  this.spaced = true,
}) extends StatelessWidget {
  /// Crea il banner; `tone` sceglie colori e icona predefinita.
  this;

  /// Gravità del problema: colore di sfondo e dell'icona.
  final PostinoBannerTone tone;

  /// Cosa sta succedendo, in breve.
  final String title;

  /// Defaults to `alert`, or `cloud-off` when offline.
  final PostinoIconData? icon;

  /// Perché succede o cosa fare.
  final String? message;

  /// Account a cui si riferisce: il suo segno precede il titolo.
  final PostinoAccountRef? account;

  /// Etichetta dell'azione principale; senza di essa non c'è il pulsante.
  final String? actionLabel;

  /// Chiamata dall'azione principale.
  final VoidCallback? onAction;

  /// Etichetta della seconda azione.
  final String? secondaryActionLabel;

  /// Chiamata dalla seconda azione.
  final VoidCallback? onSecondaryAction;

  /// Aggiunge lo spazio sotto il banner (liste di banner).
  final bool spaced;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final a = account;
    // At large text sizes the action moves under the text, or the title has no room.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    // The design's banner action: a ghost button in ink, underlined.
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
    final under = large || actions.length > 1;
    return Padding(
      padding: EdgeInsets.only(bottom: spaced ? PostinoSpacing.s2 : 0),
      child: PostinoSelectable(
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
                PostinoIcon(
                  icon ?? (tone == PostinoBannerTone.offline ? PostinoIcons.cloudOff : PostinoIcons.alert),
                  size: PostinoSize.iconLg,
                  color: switch (tone) {
                    PostinoBannerTone.danger => c.danger,
                    PostinoBannerTone.warning => c.warning,
                    PostinoBannerTone.info => c.brand,
                    PostinoBannerTone.offline => c.inkMuted,
                  },
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
                        if (message case final m?) Text(m, style: PostinoText.preview.copyWith(color: c.ink)),
                        if (under && actions.isNotEmpty)
                          // The buttons' own padding is not part of the text's edge.
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
      ),
    );
  }
}
