// PROTOTIPO (#106) — modifica proposta a molecules/postino_message_tile.dart: un parametro `labels`
// che mostra le Etichette come PostinoLabelChip sotto l'anteprima. Copia ridotta (senza Account
// della Posta unificata) per non toccare lib/.
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_avatar.dart';
import 'package:postino/design_system/atoms/postino_focus_ring.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/atoms/postino_label_chip.dart';
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// PostinoMessageTile + [labels]: the Etichette as small chips under the preview, wrapping.
class const PostinoLabeledMessageTile({
  super.key,
  required final String sender,
  required final String subject,
  required final String preview,
  required final String time,
  required final bool unread,
  required final bool starred,
  required final String semanticLabel,
  final List<String> labels = const [],
  final bool selected = false,
  final VoidCallback? onTap,
  final FocusNode? focusNode,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final d = context.density;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final large = scale > 1.5;
    final wrap = scale > 1;
    final fg = unread ? c.listItemFgUnread : c.listItemFgRead;
    final timeText = Text(
      time,
      style: unread
          ? PostinoText.metaStrong.copyWith(color: c.brand)
          : PostinoText.meta.copyWith(color: c.listItemMeta),
    );
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
                border: Border(bottom: BorderSide(color: c.listItemDivider)),
              ),
              padding: EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: d.padY),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: d.gap,
                children: [
                  PostinoAvatar(name: sender, size: d.avatar),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: PostinoSpacing.s2,
                          children: [
                            if (unread)
                              Container(
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
                                style: (unread ? PostinoText.subject : PostinoText.subjectRead).copyWith(color: fg),
                              ),
                            ),
                            if (starred)
                              PostinoIcon(PostinoIcons.star, size: PostinoSize.iconSm, color: c.star, filled: true),
                          ],
                        ),
                        if (d.previewLines > 0)
                          Text(
                            preview,
                            maxLines: wrap ? null : d.previewLines,
                            overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: PostinoText.preview.copyWith(color: c.listItemFgRead),
                          ),
                        if (labels.isNotEmpty)
                          Padding(
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
          ),
        ),
      ),
    );
  }
}
