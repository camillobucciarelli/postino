import 'package:flutter/material.dart';

import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One choice out of several, in a group of rows: [label], and a check at the end when [selected]. The whole row is
/// one control (one Tab stop, Space/Enter chooses it), read as a selectable button of an exclusive group.
class const PostinoChoiceRow({
  super.key,

  /// Nome della scelta.
  required final String label,

  /// Se è la scelta fatta.
  required final bool selected,

  /// Chiamata quando l'utente la sceglie.
  required final VoidCallback onSelected,
}) extends StatelessWidget {
  /// Crea la riga di scelta.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return MergeSemantics(
      child: Semantics(
        button: true,
        inMutuallyExclusiveGroup: true,
        checked: selected,
        child: Material(
          color: c.surface,
          child: InkWell(
            onTap: onSelected,
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
                        child: Text(label, style: PostinoText.label.copyWith(color: c.ink)),
                      ),
                      if (selected) PostinoIcon(PostinoIcons.check, color: c.brand),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
