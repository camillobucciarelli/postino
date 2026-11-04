import 'package:flutter/material.dart';

import '../atoms/postino_focus_ring.dart';
import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The last row of a PostinoLabelPicker: `plus` and [label] («Crea «Viaggi»») in `brand`, one Tab stop, a button.
class const PostinoLabelCreateRow({
  super.key,

  /// Testo della riga.
  required final String label,

  /// Chiamata al tocco, a Invio o a Spazio.
  required final VoidCallback onTap,
}) extends StatelessWidget {
  /// Crea la riga.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return MergeSemantics(
      child: Semantics(
        button: true,
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
                  padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s3, vertical: PostinoSpacing.s2),
                  child: Row(
                    spacing: PostinoSpacing.s3,
                    children: [
                      PostinoIcon(PostinoIcons.plus, color: c.brand),
                      Expanded(
                        child: SelectionContainer.disabled(
                          child: Text(label, style: PostinoText.label.copyWith(color: c.brand)),
                        ),
                      ),
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
