import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_avatar.dart';
import 'postino_focus_ring.dart';
import 'postino_icon.dart';

/// An etichetta of the message: tag icon and [name] on a `label-*` tint derived from the name
/// (the domain gives a Label no color yet). With [onRemove] it ends with a × that removes it: one Tab stop,
/// named [removeLabel] («Togli Etichetta Fatture»), a `touch-target-android` square with the focus ring;
/// without it the chip is read-only.
class const PostinoLabelChip({
  super.key,

  /// Nome dell'etichetta, da cui deriva la tinta.
  required final String name,

  /// Chiamata dalla ×; se nulla il chip è di sola lettura.
  final VoidCallback? onRemove,

  /// Nome accessibile e tooltip della ×, obbligatorio con [onRemove].
  final String? removeLabel,
}) extends StatelessWidget {
  /// Crea il chip di un'etichetta.
  this : assert(onRemove == null || removeLabel != null, 'A removable chip needs removeLabel');

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = postinoTint(context.pc, name);
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
    final remove = onRemove;
    final text = Text(
      name,
      maxLines: wrap ? null : 1,
      overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
      style: PostinoText.meta.copyWith(color: fg),
    );
    final decoration = BoxDecoration(
      color: bg,
      borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.xs)),
    );
    if (remove == null) {
      return Semantics(
        label: name,
        excludeSemantics: true,
        child: SelectionContainer.disabled(
          child: DecoratedBox(
            decoration: decoration,
            // At least 22 high: enlarged text grows it and wraps.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: PostinoSpacing.s1,
                  children: [
                    PostinoIcon(PostinoIcons.tag, size: PostinoSize.iconSm, color: fg),
                    Flexible(child: text),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    // The chip draws `control-sm` high; the × is a full touch target, overflowing it above and below.
    const inset = (PostinoSize.touchTargetAndroid - PostinoSize.controlSm) / 2;
    return SelectionContainer.disabled(
      child: Stack(
        children: [
          Positioned.fill(
            top: inset,
            bottom: inset,
            child: DecoratedBox(decoration: decoration),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PostinoSize.touchTargetAndroid),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: PostinoSpacing.s2),
                PostinoIcon(PostinoIcons.tag, size: PostinoSize.iconSm, color: fg),
                const SizedBox(width: PostinoSpacing.s1),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: inset + PostinoSpacing.s1),
                    child: Semantics(label: name, excludeSemantics: true, child: text),
                  ),
                ),
                Semantics(
                  button: true,
                  label: removeLabel,
                  excludeSemantics: true,
                  onTap: remove,
                  child: Tooltip(
                    message: removeLabel,
                    excludeFromSemantics: true,
                    child: InkWell(
                      onTap: remove,
                      customBorder: const CircleBorder(),
                      child: PostinoFocusRing(
                        borderRadius: BorderRadius.circular(PostinoRadius.full),
                        inset: true,
                        child: SizedBox.square(
                          dimension: PostinoSize.touchTargetAndroid,
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
          ),
        ],
      ),
    );
  }
}
