// PROTOTIPO (#106) — modifica proposta a atoms/postino_label_chip.dart: un `onRemove` facoltativo.
// Qui come componente a parte per non toccare lib/.
import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_avatar.dart';
import 'package:postino/design_system/atoms/postino_focus_ring.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// PostinoLabelChip with a × that removes it: the chip draws `control-sm` (32) high, the × is a
/// `touch-target-ios` (44) square, its own Tab stop, named «Togli Etichetta [name]».
class const PostinoRemovableLabelChip({super.key, required final String name, required final VoidCallback onRemove})
    extends StatelessWidget {
  static const _inset = (PostinoSize.touchTargetIos - PostinoSize.controlSm) / 2;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = postinoTint(context.pc, name);
    return SelectionContainer.disabled(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetIos),
        child: Stack(
          children: [
            Positioned.fill(
              top: _inset,
              bottom: _inset,
              child: DecoratedBox(
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(PostinoRadius.sm)),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: PostinoSpacing.s2),
                PostinoIcon(PostinoIcons.tag, size: PostinoSize.iconSm, color: fg),
                const SizedBox(width: PostinoSpacing.s1),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: _inset + PostinoSpacing.s1),
                    child: Text(name, style: PostinoText.labelSm.copyWith(color: fg)),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Togli Etichetta $name',
                  excludeSemantics: true,
                  onTap: onRemove,
                  child: Tooltip(
                    message: 'Togli',
                    child: InkWell(
                      onTap: onRemove,
                      customBorder: const CircleBorder(),
                      child: PostinoFocusRing(
                        borderRadius: BorderRadius.circular(PostinoRadius.full),
                        child: SizedBox.square(
                          dimension: PostinoSize.touchTargetIos,
                          child: Center(
                            child: PostinoIcon(PostinoIcons.close, size: PostinoSize.iconSm, color: fg),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
