import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_avatar.dart';
import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../atoms/postino_label_chip.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A Conversazione in the list (Comfortable): its latest message, and the thread [count] from 2.
/// With [account] (Posta unificata) it carries the Account's bar and the badge on the avatar;
/// inside one Account the AppBar already says where you are. [selected]: open in the detail pane.
class const PostinoMessageTile({
  super.key,

  /// Mittente dell'ultimo messaggio.
  required final String sender,

  /// Oggetto della Conversazione.
  required final String subject,

  /// Anteprima del testo.
  required final String preview,

  /// Already formatted (“09:42”, “Ieri”, “lun”, “12 mar”).
  required final String time,

  /// Se ci sono messaggi non letti.
  required final bool unread,

  /// Se la Conversazione ha la Stella.
  required final bool starred,

  /// The whole row read out as one node: state, sender, subject, Stella, Account, time.
  required final String semanticLabel,

  /// Account a cui appartiene, in Posta unificata.
  final PostinoAccountRef? account,

  /// Numero di messaggi della Conversazione.
  final int count = 1,

  /// Se è aperta nel pannello di dettaglio.
  final bool selected = false,

  /// Chiamata al tocco; senza, la riga non è un pulsante.
  final VoidCallback? onTap,

  /// The row's focus, owned by the list so it can move it with the keyboard.
  final FocusNode? focusNode,

  /// Names of the user's Etichette, as small chips under the preview (wrapping); without any the row keeps its
  /// height. Read only through [semanticLabel], which should name them.
  final List<String> labels = const [],

  /// Open Conflitto: the row shows the local version with the `alert` sign (icon, not only color); [semanticLabel] should say it.
  final bool conflict = false,

  /// Azioni semantiche personalizzate della riga (VoiceOver «azioni»): le stesse dello scorrimento.
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions,
}) extends StatelessWidget {
  /// Crea la riga di una Conversazione.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final d = context.density;
    // At large text sizes the time moves under the sender and the subject may wrap.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final large = scale > 1.5;
    // Only at large sizes (#53) sender and subject wrap without ellipsis; below, one line as the spec says.
    final wrap = large;
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
      customSemanticsActions: customSemanticsActions,
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
                border: Border(bottom: BorderSide(color: c.listItemDivider)),
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
                    padding: EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: d.padY),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: d.gap,
                      children: [
                        PostinoAvatar(
                          name: sender,
                          size: d.avatar,
                          badge: a == null
                              ? null
                              : PostinoAccountMark(color: a.color, initial: a.initial, size: PostinoSize.accountBadge),
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
                                      decoration: BoxDecoration(color: c.unread, shape: BoxShape.circle),
                                    ),
                                  Expanded(
                                    child: Text(
                                      sender,
                                      maxLines: wrap ? null : 1,
                                      overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                                      style: (unread ? PostinoText.sender : PostinoText.senderRead).copyWith(color: fg),
                                    ),
                                  ),
                                  if (count > 1)
                                    Container(
                                      key: const ValueKey('count'),
                                      padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s1),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: c.borderSubtle),
                                        borderRadius: BorderRadius.circular(PostinoRadius.xs),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: PostinoText.meta.copyWith(
                                          color: c.listItemMeta,
                                          fontFeatures: const [FontFeature.tabularFigures()],
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
                                      overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                                      style: (unread ? PostinoText.subject : PostinoText.subjectRead).copyWith(
                                        color: fg,
                                      ),
                                    ),
                                  ),
                                  if (conflict)
                                    PostinoIcon(
                                      PostinoIcons.alert,
                                      key: const ValueKey('conflict'),
                                      size: PostinoSize.iconSm,
                                      color: c.warning,
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
                                  // The preview is an excerpt: capped even when large.
                                  maxLines: wrap ? d.previewLines * 2 : d.previewLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: PostinoText.preview.copyWith(color: c.listItemFgRead),
                                ),
                              if (labels.isNotEmpty)
                                Padding(
                                  key: const ValueKey('labels'),
                                  padding: const EdgeInsets.only(top: PostinoSpacing.s1),
                                  child: Wrap(
                                    spacing: PostinoSpacing.s1,
                                    runSpacing: PostinoSpacing.s1,
                                    children: [for (final l in labels) PostinoLabelChip(name: l)],
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
