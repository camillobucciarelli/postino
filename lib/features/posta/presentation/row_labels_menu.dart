import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conversation_labels.dart';

/// The context menu of a row of the list (right click, Menu key, Maiusc+F10): «Etichette…» opens the picker on the
/// row's Conversazione and, on closing, the focus goes back to [focusNode].
class const RowLabelsMenu({
  super.key,
  required final String accountId,
  required final String messageId,
  required final String conversationId,
  required final FocusNode focusNode,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Builder(
    builder: (row) => PostinoContextMenu(
      items: [
        PostinoMenuItem(
          key: ValueKey('row-labels-$accountId-$messageId'),
          label: context.t.selettoreEtichette.menuItem,
          onPressed: () => unawaited(
            openLabelPicker(row, accountId: accountId, conversationId: conversationId, returnFocus: focusNode),
          ),
        ),
      ],
      child: child,
    ),
  );
}
