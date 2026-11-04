// PROTOTIPO (#106): the open Conversazione, with the Etichette of the current variant.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:postino/design_system/atoms/postino_button.dart';
import 'package:postino/design_system/atoms/postino_focus_ring.dart';
import 'package:postino/design_system/atoms/postino_icon.dart';
import 'package:postino/design_system/molecules/postino_message_body.dart';
import 'package:postino/design_system/organisms/postino_action_bar.dart';
import 'package:postino/design_system/organisms/postino_app_bar.dart';
import 'package:postino/design_system/organisms/postino_thread_message.dart';
import 'package:postino/design_system/organisms/postino_thread_view.dart';
import 'package:postino/design_system/templates/postino_single_pane_layout.dart';
import 'package:postino/design_system/tokens/postino_icons.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'label_flow.dart';
import 'picker_inline.dart';
import 'proto_state.dart';

class const ConversationPane({super.key, required final FakeThread thread, required final VoidCallback onBack})
    extends StatefulWidget {
  @override
  State<ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState() extends State<ConversationPane> {
  final _button = GlobalKey();
  final _buttonFocus = FocusNode(debugLabel: 'Etichette');
  final _inline = GlobalKey<InlineLabelsState>();

  void _openLabels() {
    if (proto.variant == ProtoVariant.b) return _inline.currentState?.startEditing();
    final anchor = _button.currentContext;
    if (anchor != null) unawaited(openLabelPicker(anchor, widget.thread, returnFocus: _buttonFocus));
  }

  @override
  void dispose() {
    if (proto.openLabels == _openLabels) proto.openLabels = null;
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context)..openLabels = _openLabels;
    final t = widget.thread;
    final b = s.variant == ProtoVariant.b;
    final names = t.labels.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return PostinoSinglePaneLayout(
      appBar: PostinoAppBar(
        title: '',
        onBack: MediaQuery.sizeOf(context).width >= PostinoSize.breakpointListDetail ? null : widget.onBack,
        actions: [
          if (!b) _LabelsButton(key: _button, focusNode: _buttonFocus, onPressed: _openLabels),
          const SizedBox(width: PostinoSpacing.s2),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PostinoThreadView(
              subject: t.subject,
              account: account,
              accountName: accountName,
              labels: b ? const [] : names,
              messages: [
                if (b)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(PostinoSpacing.s4, 0, PostinoSpacing.s4, PostinoSpacing.s3),
                    child: InlineLabels(key: _inline, thread: t),
                  ),
                PostinoThreadMessage(
                  sender: t.sender,
                  time: t.time,
                  preview: t.preview,
                  expanded: true,
                  onToggle: () {},
                  recipients: 'a me',
                  body: PostinoMessageBody(text: t.body),
                ),
              ],
            ),
          ),
          PostinoActionBar(
            children: [
              PostinoButton(label: 'Rispondi', onPressed: () {}),
              PostinoButton(label: 'Rispondi a tutti', variant: PostinoButtonVariant.ghost, onPressed: () {}),
              PostinoButton(label: 'Inoltra', variant: PostinoButtonVariant.ghost, onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

/// PostinoIconButton with its FocusNode, so Esc can bring the focus back here.
/// Proposta: un `focusNode` facoltativo su PostinoIconButton.
class const _LabelsButton({super.key, required final FocusNode focusNode, required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: IconButton(
      focusNode: focusNode,
      onPressed: onPressed,
      tooltip: 'Etichette',
      color: context.pc.inkMuted,
      style: ButtonStyle(
        backgroundBuilder: (context, states, child) =>
            PostinoFocusRing(borderRadius: BorderRadius.circular(PostinoRadius.full), child: child!),
      ),
      icon: const PostinoIcon(PostinoIcons.tag, size: PostinoSize.iconLg),
    ),
  );
}
