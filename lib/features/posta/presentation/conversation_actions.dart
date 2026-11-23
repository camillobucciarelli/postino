import 'package:flutter/widgets.dart';

import '../../../core/domain/mail_action.dart';
import '../../../core/domain/message.dart' show trashLabelId;
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'posta_shortcuts.dart';

/// One Azione on a Conversazione as the header and the row menu show it.
typedef ConversationAction = ({MailAction action, String label, PostinoIconData icon});

/// Whether [view] is the Cestino: Archivia gives way to Ripristina, and Elimina is not offered (#372).
bool isTrash(String? view) => view == trashLabelId;

/// The Azioni of a Conversazione, in order (#146): Archivia, Elimina (in the Cestino of [view] Ripristina only), then
/// Stella and letto/non letto as toggles of [starred] (a message has the Stella) and [read] (every message is read).
List<ConversationAction> conversationActions(
  BuildContext context, {
  required bool starred,
  required bool read,
  required String? view,
}) {
  final t = context.t.azioni;
  return [
    if (isTrash(view))
      (action: const Restore(), label: t.restore, icon: PostinoIcons.inbox)
    else ...[
      (action: const Archive(), label: t.archive, icon: PostinoIcons.archive),
      (action: const Delete(), label: t.delete, icon: PostinoIcons.trash),
    ],
    starred
        ? (action: const Unstar(), label: t.unstar, icon: PostinoIcons.star)
        : (action: const Star(), label: t.star, icon: PostinoIcons.star),
    read
        ? (action: const MarkUnread(), label: t.markUnread, icon: PostinoIcons.mail)
        : (action: const MarkRead(), label: t.markRead, icon: PostinoIcons.mailOpen),
  ];
}

/// The Azione of a shortcut; [starred]: the Conversazione has the Stella, so `s` takes it off. In the Cestino of
/// [view] `e` is Ripristina and `#` nothing.
MailAction? mailActionFor(PostaAction action, {required bool starred, required String? view}) => switch (action) {
  PostaAction.archive => isTrash(view) ? const Restore() : const Archive(),
  PostaAction.delete => isTrash(view) ? null : const Delete(),
  PostaAction.star => starred ? const Unstar() : const Star(),
  PostaAction.markRead => const MarkRead(),
  PostaAction.markUnread => const MarkUnread(),
  _ => null,
};

/// Archivia, Elimina and Ripristina take the Conversazione out of the list: the selection moves on.
bool leavesList(MailAction action) => action is Archive || action is Delete || action is Restore;
