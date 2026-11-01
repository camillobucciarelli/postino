import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The composer: the sender row, the header fields (each with its own hairline) and the editor
/// filling the rest, on `composer-bg` with `space-5` at the sides.
class PostinoComposerLayout extends StatelessWidget {
  const PostinoComposerLayout({
    super.key,
    required this.sender,
    required this.fields,
    required this.editor,
  });

  final Widget sender;
  final List<Widget> fields;
  final Widget editor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.pc.composerBg,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s5),
      child: Column(
        children: [
          sender,
          ...fields,
          Expanded(child: editor),
        ],
      ),
    ),
  );
}
