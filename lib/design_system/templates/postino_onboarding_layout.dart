// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// One onboarding step per screen; the welcome uses [title] in `display`, the main action full width at the bottom.
class const PostinoOnboardingLayout({
  super.key,

  /// Titolo del passaggio.
  required final String title,

  /// Testo di spiegazione sotto il titolo.
  required final String message,

  /// Azione principale, a larghezza piena in fondo alla schermata.
  required final Widget primaryAction,

  /// Shown above the action, e.g. a `danger` Banner.
  final Widget? error,

  /// A quieter action under the main one (e.g. Segnala un problema).
  final Widget? secondaryAction,
}) extends StatelessWidget {
  /// Crea il layout di un passaggio dell'onboarding.
  this;

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
                        if (secondaryAction case final secondary?) ...[
                          const SizedBox(height: PostinoSpacing.s2),
                          secondary,
                        ],
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
