import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/domain/mail_action.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conversation_actions.dart';
import 'conversation_labels.dart';

/// The context menu of a row of the list (right click, Menu key, Maiusc+F10): the Azioni on the row's whole
/// Conversazione (#146) and «Etichette…», which opens the picker; on closing, the focus goes back to [focusNode].
class const RowMenu({
  super.key,
  required final String accountId,
  required final String messageId,
  required final String conversationId,
  required final FocusNode focusNode,

  /// Whether every message of the Conversazione is read, and whether one has the Stella.
  required final bool read,
  required final bool starred,

  /// Archivia or Elimina of the row open beside the list: the selection moves on first.
  final VoidCallback? onLeave,
  required final Widget child,
}) extends StatelessWidget {
  Future<void> _act(BuildContext context, MailAction action) {
    if (action is Archive || action is Delete) onLeave?.call();
    return actOnStoredConversation(context, accountId, conversationId, action);
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (row) => PostinoContextMenu(
      items: [
        for (final a in conversationActions(context, starred: starred, read: read))
          PostinoMenuItem(label: a.label, icon: a.icon, onPressed: () => unawaited(_act(context, a.action))),
        PostinoMenuItem(
          key: ValueKey('row-labels-$accountId-$messageId'),
          label: context.t.selettoreEtichette.menuItem,
          icon: PostinoIcons.tag,
          onPressed: () => unawaited(
            openLabelPicker(row, accountId: accountId, conversationId: conversationId, returnFocus: focusNode),
          ),
        ),
      ],
      child: child,
    ),
  );
}
