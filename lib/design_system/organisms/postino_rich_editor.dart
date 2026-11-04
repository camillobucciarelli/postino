import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../atoms/postino_button.dart';
import '../atoms/postino_format_button.dart';
import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// The names of the formats and of the link dialog, in the user's language (the feature passes them).
class PostinoFormatLabels {
  const PostinoFormatLabels({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.link,
    required this.bulletList,
    required this.numberedList,
    required this.linkUrl,
    required this.insert,
    required this.cancel,
  });

  final String bold;
  final String italic;
  final String underline;
  final String strikethrough;
  final String link;
  final String bulletList;
  final String numberedList;
  final String linkUrl;
  final String insert;
  final String cancel;
}

class _LinkIntent extends Intent {
  const _LinkIntent();
}

class _StrikeIntent extends Intent {
  const _StrikeIntent();
}

/// The body of a message being written: a bar with the seven formats (#35) over a flutter_quill
/// editor styled with the tokens. Cmd/Ctrl+B, I, U toggle as in quill; Cmd+Shift+X strikes through;
/// Cmd+K opens the link dialog; quill's quote, code, header, checklist and image shortcuts are off.
/// Tab from the field above lands in the editor, Tab again goes on to the bar's buttons (ADR 0014).
class PostinoRichEditor extends StatefulWidget {
  const PostinoRichEditor({
    super.key,
    required this.controller,
    required this.label,
    required this.placeholder,
    this.focusNode,
    required this.labels,
  });

  final QuillController controller;
  final String label;
  final String placeholder;
  final FocusNode? focusNode;
  final PostinoFormatLabels labels;

  @override
  State<PostinoRichEditor> createState() => _PostinoRichEditorState();
}

class _PostinoRichEditorState extends State<PostinoRichEditor> {
  late final _scroll = ScrollController();
  late final _focus = widget.focusNode ?? FocusNode(debugLabel: 'Editor');

  @override
  void dispose() {
    _scroll.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  Style get _style => widget.controller.getSelectionStyle();

  bool _active(Attribute<dynamic> a) => _style.attributes[a.key]?.value == a.value;

  void _toggle(Attribute<dynamic> a) => widget.controller.formatSelection(_active(a) ? Attribute.clone(a, null) : a);

  Future<void> _link() async {
    final c = widget.controller;
    final selection = c.selection;
    final url = await showDialog<String>(context: context, builder: (context) => _LinkDialog(widget.labels));
    if (url == null || url.isEmpty) return;
    // ponytail: with nothing selected the URL itself becomes the link text.
    if (selection.isCollapsed) {
      c
        ..replaceText(selection.start, 0, url, null)
        ..updateSelection(
          TextSelection(baseOffset: selection.start, extentOffset: selection.start + url.length),
          ChangeSource.local,
        );
    } else {
      c.updateSelection(selection, ChangeSource.local);
    }
    c.formatSelection(LinkAttribute(url));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final l = widget.labels;
    final body = PostinoText.body.copyWith(color: c.ink);
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    SingleActivator key(LogicalKeyboardKey k, {bool shift = false}) =>
        SingleActivator(k, meta: mac, control: !mac, shift: shift);
    final buttons = <(PostinoIconData, String, Attribute<dynamic>)>[
      (PostinoIcons.bold, l.bold, Attribute.bold),
      (PostinoIcons.italic, l.italic, Attribute.italic),
      (PostinoIcons.underline, l.underline, Attribute.underline),
      (PostinoIcons.strikethrough, l.strikethrough, Attribute.strikeThrough),
      (PostinoIcons.listBullet, l.bulletList, Attribute.ul),
      (PostinoIcons.listNumbered, l.numberedList, Attribute.ol),
    ];
    return ColoredBox(
      color: c.composerBg,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => Wrap(
                  children: [
                    for (final (icon, label, attribute) in buttons)
                      PostinoFormatButton(
                        icon: icon,
                        label: label,
                        active: _active(attribute),
                        onPressed: () => _toggle(attribute),
                      ),
                    PostinoFormatButton(
                      icon: PostinoIcons.link,
                      label: l.link,
                      active: _style.containsKey(Attribute.link.key),
                      onPressed: _link,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: Semantics(
                  label: widget.label,
                  textField: true,
                  multiline: true,
                  child: QuillEditor.basic(
                    controller: widget.controller,
                    focusNode: _focus,
                    scrollController: _scroll,
                    config: QuillEditorConfig(
                      expands: true,
                      placeholder: widget.placeholder,
                      padding: const EdgeInsets.all(PostinoSpacing.s5),
                      // quill's bullets and numbers are plain widgets whose semantics rect ignores the
                      // editor's offset, so VoiceOver would point at the wrong place: out of the tree.
                      // ignore: experimental_member_use
                      customLeadingBlockBuilder: (node, config) => ExcludeSemantics(
                        child: config.attribute == Attribute.ol
                            ? QuillNumberPoint(
                                index: '${config.index}',
                                indentLevelCounts: config.indentLevelCounts,
                                count: config.count,
                                style: config.style!,
                                width: config.width!,
                                attrs: config.attrs,
                                padding: config.padding!,
                              )
                            : QuillBulletPoint(style: config.style!, width: config.width!, padding: config.padding!),
                      ),
                      customStyles: DefaultStyles(
                        paragraph: DefaultTextBlockStyle(
                          body,
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        lists: DefaultListBlockStyle(
                          body,
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                          null,
                        ),
                        // Bullets and numbers in ink too.
                        leading: DefaultTextBlockStyle(
                          body,
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        placeHolder: DefaultTextBlockStyle(
                          body.copyWith(color: c.inkMuted),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        link: TextStyle(color: c.brand, decoration: TextDecoration.underline),
                      ),
                      // Tab moves the focus on, as in any mail composer: quill's indent is left out
                      // before it sees the key, so the app's Tab handling takes it.
                      // ignore: experimental_member_use
                      onKeyPressed: (event, _) =>
                          event.logicalKey == LogicalKeyboardKey.tab ? KeyEventResult.ignored : null,
                      customShortcuts: {
                        key(LogicalKeyboardKey.keyX, shift: true): const _StrikeIntent(),
                        key(LogicalKeyboardKey.keyK): const _LinkIntent(),
                        // Formats outside the list of #35 stay out.
                        key(LogicalKeyboardKey.keyB, shift: true): const DoNothingIntent(),
                        key(LogicalKeyboardKey.backquote): const DoNothingIntent(),
                        key(LogicalKeyboardKey.tilde, shift: true): const DoNothingIntent(),
                        key(LogicalKeyboardKey.keyC, shift: true): const DoNothingIntent(),
                        key(LogicalKeyboardKey.keyG): const DoNothingIntent(),
                        for (final d in [
                          LogicalKeyboardKey.digit0,
                          LogicalKeyboardKey.digit1,
                          LogicalKeyboardKey.digit2,
                          LogicalKeyboardKey.digit3,
                          LogicalKeyboardKey.digit4,
                          LogicalKeyboardKey.digit5,
                          LogicalKeyboardKey.digit6,
                        ])
                          key(d): const DoNothingIntent(),
                      },
                      customActions: {
                        _StrikeIntent: CallbackAction<_StrikeIntent>(onInvoke: (_) => _toggle(Attribute.strikeThrough)),
                        _LinkIntent: CallbackAction<_LinkIntent>(onInvoke: (_) => _link()),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog(this.labels);
  final PostinoFormatLabels labels;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    void insert() => Navigator.pop(context, _url.text.trim());
    return AlertDialog(
      title: Text(l.link),
      content: TextField(
        controller: _url,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(labelText: l.linkUrl),
        onSubmitted: (_) => insert(),
      ),
      actions: [
        PostinoButton(label: l.cancel, variant: PostinoButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
        PostinoButton(label: l.insert, onPressed: insert),
      ],
    );
  }
}
