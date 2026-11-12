import 'package:injectable/injectable.dart';

import 'inbox_repository.dart';
import 'mail_sync.dart';
import 'message.dart';
import 'notification_action.dart';
import 'notification_target.dart';
import 'notifications.dart';

/// A button of a notification (#211): its Azione on the unread messages of the Conversazione in the inbox here (what
/// the notification is about; the read ones and those in other folders stay as they are), through the offline queue
/// (applied here at once, the replay tried now when the Account is attivo, ADR 0008); then the notification goes, also when the Azione leaves something unread (Stella). No Annulla: the notification
/// is gone. The same from the main isolate and from the background one (iOS, Android).
@injectable
class NotificationActionUseCase(
  final MailSync _sync,
  final InboxRepository _inbox,
  final Notifications _notifications,
) {
  /// Lega la coda delle Azioni alle notifiche.
  this;

  /// Runs [tap]; completes once the Azione is applied here and its replay ended (or could not start). From the
  /// [background] engine only the Azioni go to the Provider: the Bozze have no claim across isolates.
  Future<void> run(NotificationActionTap tap, {bool background = false}) async {
    final (:conversation, :action) = tap;
    final ids = [
      for (final (:message, body: _)
          in await _inbox.watchConversation(conversation.accountId, conversation.conversationId).first)
        if (message.labelIds.contains(inboxLabelId) && !message.isRead) message.id,
    ];
    await _sync.act(conversation.accountId, ids, action.mailAction, actionsOnly: background);
    try {
      await _notifications.cancel([ConversationTarget(conversation)]);
    } on Object catch (_) {
      // The Azione is done: a notification the OS keeps (or already took away) changes nothing.
    }
  }
}
