import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One onboarding step per screen; the welcome uses [title] in `display`, the main action full width at the bottom.
class PostinoOnboardingLayout extends StatelessWidget {
  /// Crea il layout di un passaggio dell'onboarding.
  const PostinoOnboardingLayout({
    super.key,
    required this.title,
    required this.message,
    required this.primaryAction,
    this.error,
  });

  /// Titolo del passaggio.
  final String title;

  /// Testo di spiegazione sotto il titolo.
  final String message;

  /// Azione principale, a larghezza piena in fondo alla schermata.
  final Widget primaryAction;

  /// Shown above the action, e.g. a `danger` Banner.
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      // On wide windows the step keeps a readable width, centered.
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PostinoSize.readingMaxWidth),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(PostinoSpacing.s6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: PostinoSpacing.s16),
                        Text(title, style: PostinoText.display.copyWith(color: c.ink)),
                        const SizedBox(height: PostinoSpacing.s2),
                        Text(message, style: PostinoText.body.copyWith(color: c.inkMuted)),
                        const Spacer(),
                        ?error,
                        primaryAction,
                      ],
                    ),
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
