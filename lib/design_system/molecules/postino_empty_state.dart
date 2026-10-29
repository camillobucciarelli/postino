import 'package:flutter/widgets.dart';

import '../atoms/postino_icon.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Fills a view with no content and says what comes next. Calm: no illustration, no jokes.
class PostinoEmptyState extends StatelessWidget {
  const PostinoEmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon = PostinoIcons.check,
  });

  final String title;
  final String? body;
  final PostinoIconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PostinoSpacing.s6,
        vertical: PostinoSpacing.s10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: PostinoSpacing.s2,
        children: [
          Container(
            width: PostinoSpacing.s16,
            height: PostinoSpacing.s16,
            margin: const EdgeInsets.only(bottom: PostinoSpacing.s2),
            decoration: BoxDecoration(
              color: c.surfaceSelected,
              shape: BoxShape.circle,
            ),
            child: Center(child: PostinoIcon(icon, size: 30, color: c.brand)),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PostinoText.display.copyWith(color: c.ink),
          ),
          if (body case final b?)
            ConstrainedBox(
              // About 34 characters of preview text.
              constraints: const BoxConstraints(maxWidth: 34 * 8),
              child: Text(
                b,
                textAlign: TextAlign.center,
                style: PostinoText.preview.copyWith(color: c.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}
