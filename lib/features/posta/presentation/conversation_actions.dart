import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_action.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/platform_services.dart';
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

/// [actOnConversation] on the messages of the Conversazione here (from the list: it may never have been opened).
Future<void> actOnStoredConversation(
  BuildContext context,
  String accountId,
  String conversationId,
  MailAction action,
) async {
  final messages = await GetIt.I<InboxRepository>().watchConversation(accountId, conversationId).first;
  if (!context.mounted) return;
  actOnConversation(context, accountId, [for (final m in messages) m.message.id], action);
}

/// Applies [action] to [messageIds] (a whole Conversazione) here at once. Archivia and Elimina are held for
/// `undoWindow` behind «Annulla» under [context]'s messenger: within it nothing leaves the device.
void actOnConversation(BuildContext context, String accountId, List<String> messageIds, MailAction action) {
  final t = context.t.azioni;
  final message = switch (action) {
    Archive() => t.archived,
    Delete() => t.deleted,
    _ => null,
  };
  final sync = GetIt.I<MailSync>();
  if (message == null) {
    unawaited(sync.act(accountId, messageIds, action));
    return;
  }
  final queued = sync.act(accountId, messageIds, action, hold: PostinoMotion.undoWindow);
  offerUndo(context, accountId, messageIds, action, message: message, queued: queued);
}

/// «Annulla» under [context]'s messenger for `undoWindow`, for [action] on [messageIds] [queued] with that hold:
/// it takes the voci back ([MailSync.cancelAction]) and the Provider never hears of them.
void offerUndo(
  BuildContext context,
  String accountId,
  List<String> messageIds,
  MailAction action, {
  required String message,
  required Future<void> queued,
}) {
  final clock = GetIt.I<Clock>();
  PostinoSnackbar.show(
    context,
    message: message,
    actionLabel: context.t.azioni.undo,
    until: clock.now().add(PostinoMotion.undoWindow),
    now: clock.now,
    // After the queueing: an Annulla quicker than the database finds nothing to take back otherwise.
    onAction: () => unawaited(queued.then((_) => GetIt.I<MailSync>().cancelAction(accountId, messageIds, action))),
  );
}
