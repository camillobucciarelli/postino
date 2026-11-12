import 'package:injectable/injectable.dart';

import 'inbox_repository.dart';
import 'mail_sync.dart';
import 'notification_action.dart';
import 'notification_target.dart';
import 'notifications.dart';

/// A button of a notification (#211): its Azione on the messages of the Conversazione here, as a swipe of its row
/// does, through the offline queue (applied here at once, the replay tried now when the Account is attivo, ADR 0008);
/// then the notification goes, also when the Azione leaves something unread (Stella). No Annulla: the notification
/// is gone. The same from the main isolate and from the background one (iOS, Android).
@injectable
class NotificationActionUseCase(
  final MailSync _sync,
  final InboxRepository _inbox,
  final Notifications _notifications,
) {
  /// Lega la coda delle Azioni alle notifiche.
  this;

  /// Runs [tap]; completes once the Azione is applied here and its replay ended (or could not start).
  Future<void> run(NotificationActionTap tap) async {
    final (:conversation, :action) = tap;
    final ids = [
      for (final m in await _inbox.watchConversation(conversation.accountId, conversation.conversationId).first)
        m.message.id,
    ];
    await _sync.act(conversation.accountId, ids, action.mailAction);
    try {
      await _notifications.cancel([ConversationTarget(conversation)]);
    } on Object catch (_) {
      // The Azione is done: a notification the OS keeps (or already took away) changes nothing.
    }
  }
}
