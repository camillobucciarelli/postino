// PROTOTIPO (#106) — componente proposto per il design system (atomo).
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_focus_ring.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'proto_icons.dart';

/// «+ Etichetta»: the chip that adds one more, outlined in `border-strong` on the surface,
/// `touch-target-ios` high; [semanticLabel] says the action in full («Aggiungi Etichetta»).
class const PostinoAddChip({
  super.key,
  required final String label,
  required final String semanticLabel,
  required final VoidCallback onPressed,
  final FocusNode? focusNode,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    const radius = BorderRadius.all(Radius.circular(PostinoRadius.sm));
    return SelectionContainer.disabled(
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: onPressed,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            focusNode: focusNode,
            onTap: onPressed,
            borderRadius: radius,
            child: PostinoFocusRing(
              borderRadius: radius,
              child: Container(
                constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetIos),
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: c.borderStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: PostinoSpacing.s1,
                  children: [
                    PostinoIcon(ProtoIcons.plus, size: PostinoSize.iconSm, color: c.inkMuted),
                    Flexible(
                      child: Text(label, style: PostinoText.labelSm.copyWith(color: c.ink)),
                    ),
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
