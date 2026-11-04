// PROTOTIPO (#106) — componente proposto per il design system (molecola).
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_focus_ring.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// A row of the settings: [title] (a UI label, not selectable), an optional [subtitle], a [trailing] control.
/// With [onTap] the whole row is the one focus stop and the control inside should not be focusable
/// (PostinoSwitch(focusable: false)); its semantics merge, «Fatture, Automatica, interruttore, attivo».
class const PostinoSettingsItem({
  super.key,
  required final String title,
  final String? subtitle,
  final Widget? trailing,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return MergeSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: PostinoFocusRing(
            inset: true,
            borderRadius: BorderRadius.circular(PostinoRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3, vertical: PostinoSpacing.s1),
                child: Row(
                  spacing: PostinoSpacing.s3,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectionContainer.disabled(
                            child: Text(title, style: PostinoText.label.copyWith(color: c.ink)),
                          ),
                          if (subtitle case final s?) Text(s, style: PostinoText.caption.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
