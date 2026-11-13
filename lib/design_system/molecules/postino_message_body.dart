// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_button.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The body of an expanded message: its [text] in `body` (selectable through the Conversazione's SelectionArea);
/// or, while it is not there, a quiet note and maybe a retry.
class PostinoMessageBody extends StatelessWidget {
  /// Crea il corpo con `text` da mostrare.
  const PostinoMessageBody({super.key, required String this.text, this.quiet = false})
    : note = null,
      actionLabel = null,
      onAction = null;

  /// No body yet: [note] says why (“Caricamento…”, “Corpo non disponibile offline”), [actionLabel] retries.
  const PostinoMessageBody.missing({super.key, required String this.note, this.actionLabel, this.onAction})
    : text = null,
      quiet = false;

  /// Testo del corpo; null se manca.
  final String? text;

  /// Perché il corpo non c'è; null se il testo c'è.
  final String? note;

  /// Etichetta del pulsante di nuovo tentativo, se serve.
  final String? actionLabel;

  /// Chiamata dal pulsante di nuovo tentativo.
  final VoidCallback? onAction;

  /// A signature or a quote: `body-quote` in `ink-muted`.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    if (text case final t?) {
      return Text(
        t,
        style: quiet ? PostinoText.bodyQuote.copyWith(color: c.inkMuted) : PostinoText.body.copyWith(color: c.ink),
      );
    }
    final label = actionLabel;
    return Row(
      spacing: PostinoSpacing.s2,
      children: [
        Flexible(
          child: Text(note!, style: PostinoText.preview.copyWith(color: c.inkMuted)),
        ),
        if (label != null)
          PostinoButton(
            label: label,
            onPressed: onAction,
            variant: PostinoButtonVariant.ghost,
            size: PostinoButtonSize.sm,
          ),
      ],
    );
  }
}
