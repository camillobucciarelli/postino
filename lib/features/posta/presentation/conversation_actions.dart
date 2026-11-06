import 'package:flutter/widgets.dart';

import '../../../core/domain/mail_action.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'posta_shortcuts.dart';

/// One Azione on a Conversazione as the header and the row menu show it.
typedef ConversationAction = ({MailAction action, String label, PostinoIconData icon});

/// The Azioni of a Conversazione, in order (#146): Archivia, Elimina, then Stella and letto/non letto as toggles
/// of [starred] (a message has the Stella) and [read] (every message is read).
List<ConversationAction> conversationActions(BuildContext context, {required bool starred, required bool read}) {
  final t = context.t.azioni;
  return [
    (action: const Archive(), label: t.archive, icon: PostinoIcons.archive),
    (action: const Delete(), label: t.delete, icon: PostinoIcons.trash),
    starred
        ? (action: const Unstar(), label: t.unstar, icon: PostinoIcons.star)
        : (action: const Star(), label: t.star, icon: PostinoIcons.star),
    read
        ? (action: const MarkUnread(), label: t.markUnread, icon: PostinoIcons.mail)
        : (action: const MarkRead(), label: t.markRead, icon: PostinoIcons.mailOpen),
  ];
}

/// The Azione of a shortcut; [starred]: the Conversazione has the Stella, so `s` takes it off.
MailAction? mailActionFor(PostaAction action, {required bool starred}) => switch (action) {
  PostaAction.archive => const Archive(),
  PostaAction.delete => const Delete(),
  PostaAction.star => starred ? const Unstar() : const Star(),
  PostaAction.markRead => const MarkRead(),
  PostaAction.markUnread => const MarkUnread(),
  _ => null,
};

/// Archivia and Elimina take the Conversazione out of the list: the selection moves on.
bool leavesList(MailAction action) => action is Archive || action is Delete;
