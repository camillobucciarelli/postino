import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import '../../../core/domain/mail_action.dart';
import '../../../core/domain/swipe_actions.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'act_on_conversation.dart';
import 'conversation_labels.dart';

/// Swiping a row of the list (#147): the Azione the Impostazioni bind to each direction, on the row's whole
/// Conversazione, through the flow of #146 (same «Annulla»). «Applica Etichetta» opens the picker; closing it
/// without a choice leaves the row as it was. [builder] makes the row, with the same two Azioni as semantic actions
/// (VoiceOver «azioni»), since a swipe is pointer only.
class const RowSwipe({
  super.key,
  required final String accountId,
  required final String conversationId,
  required final bool labelsAreFolders,

  /// Whether every message of the Conversazione is read, and whether one has the Stella.
  required final bool read,
  required final bool starred,

  /// The row's focus: it gets it back when the picker closes.
  required final FocusNode focusNode,
  required final SwipeActions actions,

  /// The Azioni of the Conversazione open beside the list, when it is this row's (see `RowMenu.onOpenAct`).
  final void Function(MailAction action)? onOpenAct,
  required final Widget Function(Map<CustomSemanticsAction, VoidCallback> semanticActions) builder,
}) extends StatelessWidget {
  ({MailAction? action, PostinoSwipeAction shown}) _view(BuildContext context, SwipeAction choice) {
    final t = context.t.azioni;
    return switch (choice) {
      SwipeAction.archive => (
        action: const Archive(),
        shown: (label: t.archive, icon: PostinoIcons.archive, tone: PostinoSwipeTone.archive),
      ),
      SwipeAction.delete => (
        action: const Delete(),
        shown: (label: t.delete, icon: PostinoIcons.trash, tone: PostinoSwipeTone.delete),
      ),
      SwipeAction.star => (
        action: starred ? const Unstar() : const Star(),
        shown: (label: starred ? t.unstar : t.star, icon: PostinoIcons.star, tone: PostinoSwipeTone.star),
      ),
      SwipeAction.markRead => (
        action: read ? const MarkUnread() : const MarkRead(),
        shown: read
            ? (label: t.markUnread, icon: PostinoIcons.mail, tone: PostinoSwipeTone.read)
            : (label: t.markRead, icon: PostinoIcons.mailOpen, tone: PostinoSwipeTone.read),
      ),
      SwipeAction.applyLabel => (
        action: null,
        shown: (label: t.applyLabel, icon: PostinoIcons.tag, tone: PostinoSwipeTone.label),
      ),
    };
  }

  @override
  Widget build(BuildContext context) => Builder(
    // The picker anchors to the row, which stays where it is: this context is outside the swiping part.
    builder: (row) {
      void run(SwipeAction choice) {
        final MailAction? action = _view(row, choice).action;
        if (action != null) {
          return actOnRow(row, accountId, conversationId, action, onOpenAct: onOpenAct);
        }
        unawaited(
          openLabelPicker(
            row,
            accountId: accountId,
            conversationId: conversationId,
            labelsAreFolders: labelsAreFolders,
            returnFocus: focusNode,
          ),
        );
      }

      final left = _view(row, actions.left).shown;
      final right = _view(row, actions.right).shown;
      return PostinoSwipeRow(
        left: left,
        right: right,
        onSwipe: (side) => run(side == PostinoSwipeSide.left ? actions.left : actions.right),
        child: builder({
          CustomSemanticsAction(label: left.label): () => run(actions.left),
          CustomSemanticsAction(label: right.label): () => run(actions.right),
        }),
      );
    },
  );
}
