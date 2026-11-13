// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A row of the Impostazioni that opens a page: [title] (a UI label, not selectable), an optional [subtitle],
/// `chevron-right` at the end. The whole row is one control, one Tab stop, read as a button. Without [onTap] it only
/// shows something (for example an Account): no chevron, no button. [trailing] is a control of its own at the end
/// (for example «Rimuovi» on an Account): its own Tab stop and accessible name, outside the row's.
/// For a setting that is on or off use PostinoSwitchRow.
class const PostinoSettingsItem({
  super.key,

  /// Nome della voce.
  required final String title,

  /// Chiamata al tocco: apre la pagina della voce; null per una voce che mostra soltanto.
  required final VoidCallback? onTap,

  /// Dettaglio sotto il titolo, per esempio lo stato attuale.
  final String? subtitle,

  /// Comando a parte in fondo alla voce, per esempio un PostinoIconButton.
  final Widget? trailing,
}) extends StatelessWidget {
  /// Crea la voce.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final item = MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: Material(
          color: c.surface,
          child: InkWell(
            onTap: onTap,
            child: PostinoFocusRing(
              inset: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.listItemDivider)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: PostinoSpacing.s3),
                child: SelectionContainer.disabled(
                  child: Row(
                    spacing: PostinoSpacing.s3,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: PostinoSpacing.s0_5,
                          children: [
                            Text(title, style: PostinoText.label.copyWith(color: c.ink)),
                            if (subtitle case final s?) Text(s, style: PostinoText.caption.copyWith(color: c.inkMuted)),
                          ],
                        ),
                      ),
                      if (onTap != null) PostinoIcon(PostinoIcons.chevronRight, color: c.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (trailing == null) return item;
    // Same surface and divider as the row, so the control sits inside it.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.listItemDivider)),
      ),
      child: Row(
        children: [
          Expanded(child: item),
          Padding(
            padding: const EdgeInsets.only(right: PostinoSpacing.s2),
            child: trailing,
          ),
        ],
      ),
    );
  }
}
