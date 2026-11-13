import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/notifications.dart';
import '../daos/messages_dao_notifications.dart';
import '../postino_database.dart';

/// Removes the notifications that no longer hold anything to read (#238): a message's, once it is no longer unread in
/// the inbox (read, archived or deleted, elsewhere or here), whatever the rest of its Conversazione; the Account's group
/// summary follows. Cancelling a notification not shown is harmless, so no record of them is kept: the rule holds after
/// a restart and from any isolate (#212).
@lazySingleton
class NotificationCleanup(final PostinoDatabase _db, final Notifications _notifications) {
  /// After [messageIds] changed (or went): their notification goes if they are no longer unread in the inbox.
  Future<void> clean(String accountId, Set<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      final unread = await _db.messagesDao.unreadInInbox(accountId, messageIds);
      await _notifications.cancel(accountId, messageIds.difference(unread));
    } on Object catch (e) {
      // The type only: the error may quote the message.
      debugPrint('[notifiche] $accountId: cleanup failed, ${e.runtimeType}');
    }
  }

  /// After the Conversazione [conversationId] was read here: clean all its messages.
  Future<void> cleanConversation(String accountId, String conversationId) async {
    try {
      await clean(accountId, await _db.messagesDao.messagesOf(accountId, conversationId));
    } on Object catch (e) {
      debugPrint('[notifiche] $accountId: cleanup failed, ${e.runtimeType}');
    }
  }
}
