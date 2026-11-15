import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_selectable.dart';
import '../organisms/postino_app_bar.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_single_pane_layout.dart';

/// A page of the Impostazioni: the bar with [title], [subtitle] and the mark of the [account] it is about
/// ([onBack] leads it with `arrow-left`), the [intro] (selectable, it explains), then the [sections]
/// (PostinoSettingsSection, or rows on their own), in a column at most `reading-max-width` wide.
class const PostinoSettingsPage({
  super.key,

  /// Titolo della pagina.
  required final String title,

  /// Le sezioni della pagina, nell'ordine mostrato.
  required final List<Widget> sections,

  /// Dove si trova la pagina, per esempio «Impostazioni · Lavoro».
  final String? subtitle,

  /// Account di cui si parla: il suo segno sta accanto al titolo.
  final PostinoAccountRef? account,

  /// Freccia indietro; se nulla, il menu del drawer.
  final VoidCallback? onBack,

  /// Testo introduttivo, selezionabile.
  final String? intro,

  /// Drawer di navigazione facoltativo.
  final Widget? drawer,
}) extends StatelessWidget {
  /// Crea la pagina.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return PostinoSinglePaneLayout(
      appBar: PostinoAppBar(title: title, subtitle: subtitle, account: account, onBack: onBack),
      drawer: drawer,
      body: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth < PostinoSize.breakpointMedium ? PostinoSpacing.s4 : PostinoSpacing.s6;
          final extra = math.max(0, (box.maxWidth - PostinoSize.readingMaxWidth) / 2);
          return ListView(
            padding: EdgeInsets.fromLTRB(side + extra, PostinoSpacing.s4, side + extra, PostinoSpacing.s16),
            children: [
              if (intro case final i?)
                Padding(
                  // In line with the rows' text.
                  padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4),
                  child: PostinoSelectable(
                    child: Text(i, style: PostinoText.preview.copyWith(color: c.inkMuted)),
                  ),
                ),
              ...sections,
            ],
          );
        },
      ),
    );
  }
}
