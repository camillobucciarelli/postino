import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The composer: the sender row, the header fields (each with its own hairline) and the editor
/// filling the rest, on `composer-bg` with `space-5` at the sides.
class PostinoComposerLayout extends StatelessWidget {
  /// Crea il layout del compositore con mittente, campi di intestazione ed editor.
  const PostinoComposerLayout({super.key, required this.sender, required this.fields, required this.editor});

  /// La riga del mittente, in cima.
  final Widget sender;

  /// I campi di intestazione, ciascuno con il proprio separatore.
  final List<Widget> fields;

  /// L'editor, che occupa lo spazio rimasto.
  final Widget editor;

  /// The least height the editor keeps (toolbar and a few lines of text).
  static const minEditorHeight = 200.0;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.pc.composerBg,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s5),
      // Headers then editor in one scroll: the editor fills what the headers leave, and keeps
      // [minEditorHeight] when a landscape phone or the keyboard leaves less (then everything scrolls).
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: Column(children: [sender, ...fields])),
          SliverLayoutBuilder(
            builder: (context, c) => SliverToBoxAdapter(
              child: SizedBox(
                height: math.max(minEditorHeight, c.viewportMainAxisExtent - c.precedingScrollExtent),
                child: editor,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
