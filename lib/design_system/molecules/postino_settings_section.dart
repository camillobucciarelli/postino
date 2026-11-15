// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A group of the Impostazioni: [title] in `overline` (a heading for the screen reader), in line with the rows' text,
/// then its [children], touching as in a list.
class const PostinoSettingsSection({
  super.key,

  /// Titolo della sezione, mostrato in maiuscolo.
  required final String title,

  /// Le voci della sezione.
  required final List<Widget> children,
}) extends StatelessWidget {
  /// Crea la sezione.
  this;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PostinoSpacing.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PostinoSpacing.s4, 0, PostinoSpacing.s4, PostinoSpacing.s2),
          child: Semantics(
            header: true,
            child: SelectionContainer.disabled(
              child: Text(title.toUpperCase(), style: PostinoText.overline.copyWith(color: context.pc.inkSubtle)),
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}
