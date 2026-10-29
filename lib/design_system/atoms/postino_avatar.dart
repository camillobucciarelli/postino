import 'package:flutter/widgets.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The sender: initials on a muted `label-*` tint derived from [name]; [badge] (an AccountMark) bottom right.
/// Always decorative: the sender is written next to it.
class PostinoAvatar extends StatelessWidget {
  const PostinoAvatar({
    super.key,
    required this.name,
    this.size = PostinoSize.avatarMd,
    this.badge,
  });

  final String name;
  final double size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final tints = [
      (c.labelStoneBg, c.labelStoneFg),
      (c.labelSandBg, c.labelSandFg),
      (c.labelSageBg, c.labelSageFg),
      (c.labelSeaBg, c.labelSeaFg),
      (c.labelLilacBg, c.labelLilacFg),
      (c.labelBlushBg, c.labelBlushFg),
    ];
    final (bg, fg) = tints[_hash(name) % tints.length];
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Text(
                _initials(name),
                textScaler: TextScaler.noScaling,
                style: PostinoText.label.copyWith(
                  color: fg,
                  fontSize: (size * .36).roundToDouble(),
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
            if (badge case final b?)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.all(PostinoBorder.accountBadgeRing),
                  decoration: BoxDecoration(
                    color: c.avatarBadgeRing,
                    borderRadius: BorderRadius.circular(size * .15),
                  ),
                  child: b,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Same hash as the design system's preview, so a name gets the same tint.
int _hash(String s) {
  var n = 0;
  for (final u in s.codeUnits) {
    n = (n * 31 + u) & 0xFFFFFFFF;
  }
  return n;
}

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w.characters.first)
    .join()
    .toUpperCase();
