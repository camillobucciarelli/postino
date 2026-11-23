import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_action.dart';
import '../../../core/domain/swipe_actions.dart';
import '../domain/inbox_sections.dart';
import 'row_keep_alive.dart';
import 'row_menu.dart';
import 'row_swipe.dart';

/// A Conversazione's row: [tile] with the swipe and the menu of its Azioni, kept alive while it is the cursor
/// ([keep]). A Bozza or a queued Inviati row (its Conversazione is its Message-ID) is no Conversazione: the tile alone.
/// [onOpenAct]: the Azioni of the open Conversazione, when it is this row's.
Widget conversationRow(
  InboxEntry entry, {
  required FocusNode node,
  required bool keep,
  required SwipeActions swipeActions,
  required String view,
  required void Function(MailAction action)? onOpenAct,
  required Widget Function([Map<CustomSemanticsAction, VoidCallback>? semanticActions]) tile,
}) {
  final InboxEntry(message: m, account: a, :unread) = entry;
  final starred = isStarred(entry);
  return RowKeepAlive(
    keep: keep,
    child: m.conversationId.startsWith('<')
        ? tile()
        : RowSwipe(
            accountId: a.id,
            conversationId: m.conversationId,
            labelsAreFolders: a.provider.labelsAreFolders,
            read: !unread,
            starred: starred,
            focusNode: node,
            actions: swipeActions,
            onOpenAct: onOpenAct,
            view: view,
            builder: (semanticActions) => RowMenu(
              accountId: a.id,
              messageId: m.id,
              conversationId: m.conversationId,
              focusNode: node,
              labelsAreFolders: a.provider.labelsAreFolders,
              read: !unread,
              starred: starred,
              onOpenAct: onOpenAct,
              view: view,
              child: tile(semanticActions),
            ),
          ),
  );
}
