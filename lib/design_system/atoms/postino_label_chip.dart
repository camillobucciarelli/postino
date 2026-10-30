import 'package:flutter/widgets.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_avatar.dart';
import 'postino_icon.dart';

/// An etichetta of the message: tag icon and [name] on a `label-*` tint derived from the name
/// (the domain gives a Label no color yet).
class PostinoLabelChip extends StatelessWidget {
  const PostinoLabelChip({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = postinoTint(context.pc, name);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(
            Radius.circular(PostinoRadius.xs),
          ),
        ),
        child: SizedBox(
          height: 22,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: PostinoSpacing.s1,
              children: [
                PostinoIcon(
                  PostinoIcons.tag,
                  size: PostinoSize.iconSm,
                  color: fg,
                ),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PostinoText.meta.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
