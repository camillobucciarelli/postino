import 'package:flutter/widgets.dart';

import '../atoms/postino_icon.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// Fills a view with no content and says what comes next. Calm: no illustration, no jokes.
class const PostinoEmptyState({
  super.key,

  /// Cosa si vede: una frase breve e calma.
  required final String title,

  /// Cosa succede dopo o cosa fare, se serve.
  final String? body,

  /// Icona nel cerchio; di default la spunta.
  final PostinoIconData icon = PostinoIcons.check,
}) extends StatelessWidget {
  /// Crea lo stato vuoto; senza `body` mostra solo il titolo.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    // Centred when there is room, scrollable when the pane is shorter than the content (low window, big text).
    return PostinoSelectable(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s6, vertical: PostinoSpacing.s10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: PostinoSpacing.s2,
              children: [
                Container(
                  width: PostinoSpacing.s16,
                  height: PostinoSpacing.s16,
                  margin: const EdgeInsets.only(bottom: PostinoSpacing.s2),
                  decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle),
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
          ),
        ),
      ),
    );
  }
}
