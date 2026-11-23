import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/domain/mail_action.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'act_on_conversation.dart';
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

  /// Whether the Account's Etichette are folders: the picker offers Annulla on an addition.
  required final bool labelsAreFolders,

  /// Whether every message of the Conversazione is read, and whether one has the Stella.
  required final bool read,
  required final bool starred,

  /// The Azioni of the Conversazione open beside the list, when it is this row's: they go through it, which moves
  /// the selection on or closes it.
  final void Function(MailAction action)? onOpenAct,

  /// The Etichetta of the list: the Azioni and the picker reach only the messages it shows.
  final String? view,
  required final Widget child,
}) extends StatelessWidget {
  void _act(BuildContext context, MailAction action) =>
      actOnRow(context, accountId, conversationId, action, onOpenAct: onOpenAct, view: view);

  @override
  Widget build(BuildContext context) => Builder(
    builder: (row) => PostinoContextMenu(
      items: [
        for (final a in conversationActions(context, starred: starred, read: read, view: view))
          PostinoMenuItem(label: a.label, icon: a.icon, onPressed: () => _act(context, a.action)),
        PostinoMenuItem(
          key: ValueKey('row-labels-$accountId-$messageId'),
          label: context.t.selettoreEtichette.menuItem,
          icon: PostinoIcons.tag,
          onPressed: () => unawaited(
            openLabelPicker(
              row,
              accountId: accountId,
              conversationId: conversationId,
              labelsAreFolders: labelsAreFolders,
              returnFocus: focusNode,
              view: view,
            ),
          ),
        ),
      ],
      child: child,
    ),
  );
}
