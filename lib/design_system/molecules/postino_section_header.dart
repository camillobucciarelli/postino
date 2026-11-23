// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_button.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The heading of a section of a list (#366): [title] and [count] in `overline`, as the groups of the Impostazioni,
/// read by the screen reader as one heading ([semanticLabel]); with [onAction], a ghost button at the end
/// («Mostra tutti») that goes under the title when the text is large.
class const PostinoSectionHeader({
  super.key,

  /// Nome della sezione, mostrato in maiuscolo.
  required final String title,

  /// Numero di elementi della sezione, mostrato accanto al nome.
  required final int count,

  /// Ciò che legge lo screen reader: nome e conteggio in parole.
  required final String semanticLabel,

  /// Verbo del pulsante in fondo; senza [onAction] il pulsante non c'è.
  final String? actionLabel,

  /// Ciò che legge lo screen reader del pulsante, es. «Mostra tutte le 12 Contrassegnate».
  final String? actionSemanticLabel,

  /// Chiamata dal pulsante.
  final VoidCallback? onAction,
}) extends StatelessWidget {
  /// Crea l'intestazione.
  this;

  @override
  Widget build(BuildContext context) {
    final action = onAction;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PostinoSpacing.s4, PostinoSpacing.s4, PostinoSpacing.s2, PostinoSpacing.s1),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            container: true,
            header: true,
            label: semanticLabel,
            excludeSemantics: true,
            child: SelectionContainer.disabled(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: PostinoSpacing.s2),
                child: Text(
                  '${title.toUpperCase()}  $count',
                  style: PostinoText.overline.copyWith(color: context.pc.inkSubtle),
                ),
              ),
            ),
          ),
          if (action != null)
            Semantics(
              container: true,
              button: true,
              label: actionSemanticLabel ?? actionLabel,
              onTap: action,
              excludeSemantics: true,
              child: PostinoButton(
                label: actionLabel ?? '',
                onPressed: action,
                variant: PostinoButtonVariant.ghost,
                size: PostinoButtonSize.sm,
              ),
            ),
        ],
      ),
    );
  }
}
