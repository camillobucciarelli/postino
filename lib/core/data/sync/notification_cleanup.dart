import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/notification_target.dart';
import '../../domain/notifications.dart';
import '../daos/messages_dao_notifications.dart';
import '../postino_database.dart';

/// Removes the notifications that no longer hold anything to read (#210): a Conversazione's, once it has no unread
/// message in the inbox (read, archived or deleted, elsewhere or here); an Account's summary, once its inbox has no
/// unread Conversazione left. Cancelling a notification not shown is harmless, so no record of them is kept: the rule
/// holds after a restart and from any isolate (#212).
// ponytail: the summary goes only with the last unread of its inbox; remember the messages it counted if it lingers.
@lazySingleton
class NotificationCleanup(final PostinoDatabase _db, final Notifications _notifications) {
  /// The Conversazioni of [messageIds], looked up before a change removes the messages from the database.
  Future<Set<String>> conversationsOf(String accountId, Iterable<String> messageIds) =>
      _db.messagesDao.conversationsOf(accountId, messageIds);

  /// After [conversationIds] changed: their notification goes if they are no longer unread in the inbox.
  Future<void> clean(String accountId, Set<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    try {
      final unread = await _db.messagesDao.unreadInInbox(accountId, conversationIds);
      await _notifications.cancel([
        for (final c in conversationIds.difference(unread))
          ConversationTarget((accountId: accountId, conversationId: c)),
        if (!await _db.messagesDao.hasUnreadInInbox(accountId)) AccountTarget(accountId),
      ]);
    } on Object catch (e) {
      // The type only: the error may quote the message.
      debugPrint('[notifiche] $accountId: cleanup failed, ${e.runtimeType}');
    }
  }
}
