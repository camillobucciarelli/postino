import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:postino/design_system/organisms/postino_thread_message.dart' show PostinoThreadMessage;

import '../atoms/postino_account_mark.dart';
import '../atoms/postino_icon.dart';
import '../atoms/postino_label_chip.dart';
import '../atoms/postino_selectable.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A Conversazione: [subject] in `title` (with the Importante mark when [importantLabel] is given),
/// the Account that received it, then its [messages] (newest first, [PostinoThreadMessage]);
/// at most `reading-max-width` wide.
class const PostinoThreadView({
  super.key,
  required this.subject,
  required this.account,
  required this.accountName,
  required this.messages,
  this.labels = const [],
  this.importantLabel,
}) extends StatefulWidget {
  /// Crea la vista di una conversazione con oggetto, account e messaggi.
  this;

  /// Oggetto della conversazione, mostrato come titolo.
  final String subject;

  /// Account che ha ricevuto la conversazione, indicato con il suo contrassegno.
  final PostinoAccountRef account;

  /// Nome dell'account mostrato accanto al contrassegno.
  final String accountName;

  /// I messaggi della conversazione, dal più recente al più vecchio.
  final List<Widget> messages;

  /// Names of the etichette of the Conversazione, as [PostinoLabelChip]s after the Account.
  final List<String> labels;

  /// «Importante»: the Conversazione is important; the mark after the subject says it to screen readers.
  final String? importantLabel;

  @override
  State<PostinoThreadView> createState() => _PostinoThreadViewState();
}

class _PostinoThreadViewState() extends State<PostinoThreadView> {
  final _area = GlobalKey<SelectionAreaState>();
  bool _selected = false;

  /// Out of the Tab order, so Tab and the first focus (the back button) stay as before; a click still focuses it.
  final _focus = FocusNode(debugLabel: 'Conversazione', skipTraversal: true);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final important = widget.importantLabel;
    final wrap = MediaQuery.textScalerOf(context).scale(1) > 1;
    final subject = widget.subject;
    // One SelectionArea for the whole Conversazione: a selection crosses subject, headers and bodies,
    // and Cmd+A stays inside it. Controls opt out with SelectionContainer.disabled.
    // ponytail: the ListView builds lazily, so Cmd+A copies the messages built so far, not the off-screen ones.
    return Actions(
      actions: {
        PostinoClearSelectionIntent: _ClearSelection(() => _selected, () {
          _area.currentState?.selectableRegion.clearSelection();
          // A programmatic clear does not call onSelectionChanged.
          _selected = false;
        }),
      },
      child: SelectionArea(
        key: _area,
        focusNode: _focus,
        onSelectionChanged: (content) => _selected = content != null && content.plainText.isNotEmpty,
        child: _content(context, c, important, wrap, subject),
      ),
    );
  }

  Widget _content(BuildContext context, PostinoColors c, String? important, bool wrap, String subject) {
    final w = widget;
    // The list spans the pane (its scrollbar at the pane's edge); the margins center a column
    // of at most `reading-max-width`.
    return LayoutBuilder(
      builder: (context, box) => ListView(
        padding: EdgeInsets.fromLTRB(
          math.max(0, (box.maxWidth - PostinoSize.readingMaxWidth) / 2),
          0,
          math.max(0, (box.maxWidth - PostinoSize.readingMaxWidth) / 2),
          PostinoSpacing.s4,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PostinoSpacing.s4,
              PostinoSpacing.s4,
              PostinoSpacing.s4,
              PostinoSpacing.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PostinoSpacing.s2,
              children: [
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: subject),
                        if (important != null) ...[
                          const TextSpan(text: ' '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: PostinoIcon(
                              PostinoIcons.important,
                              key: const ValueKey('important'),
                              color: c.star,
                              filled: true,
                              label: important,
                            ),
                          ),
                        ],
                      ],
                    ),
                    style: PostinoText.title.copyWith(color: c.ink),
                  ),
                ),
                Wrap(
                  spacing: PostinoSpacing.s2,
                  runSpacing: PostinoSpacing.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: PostinoSpacing.s2,
                      children: [
                        PostinoAccountMark(
                          color: w.account.color,
                          initial: w.account.initial,
                          size: PostinoSize.accountBadge,
                        ),
                        Flexible(
                          child: Text(
                            w.accountName,
                            maxLines: wrap ? null : 1,
                            overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: PostinoText.labelSm.copyWith(color: c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    for (final l in w.labels) PostinoLabelChip(name: l),
                  ],
                ),
              ],
            ),
          ),
          ...w.messages,
        ],
      ),
    );
  }
}

/// Esc over a selection clears it; with none it is off, so the layout closes the Conversazione.
class _ClearSelection(this.selected, this.clear) extends Action<PostinoClearSelectionIntent> {
  final bool Function() selected;
  final VoidCallback clear;

  @override
  bool isEnabled(PostinoClearSelectionIntent intent) => selected();

  @override
  Object? invoke(PostinoClearSelectionIntent intent) {
    clear();
    return null;
  }
}
