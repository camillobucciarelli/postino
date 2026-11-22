import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/notifications.dart';
import '../daos/messages_dao_notifications.dart';
import '../postino_database.dart';
import 'new_mail_notifier.dart' show notificationWithin;

/// Removes the notifications that no longer hold anything to read (#238): a message's, once it is no longer unread in
/// the inbox (read, archived or deleted, elsewhere or here), whatever the rest of its Conversazione; the Account's group
/// summary follows. Cancelling a notification not shown is harmless, so no record of them is kept: the rule holds after
/// a restart and from any isolate (#212).
@lazySingleton
class NotificationCleanup(final PostinoDatabase _db, final Notifications _notifications) {
  /// After [messageIds] changed (or went): their notification goes if they are no longer unread in the inbox.
  Future<void> clean(String accountId, Set<String> messageIds) =>
      _safely(accountId, () => _clean(accountId, messageIds));

  /// After the Conversazione [conversationId] was read here: clean all its messages.
  Future<void> cleanConversation(String accountId, String conversationId) =>
      _safely(accountId, () async => _clean(accountId, await _db.messagesDao.messagesOf(accountId, conversationId)));

  Future<void> _clean(String accountId, Set<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final unread = await _db.messagesDao.unreadInInbox(accountId, messageIds);
    await _notifications.cancel(accountId, messageIds.difference(unread)).timeout(notificationWithin);
  }

  /// A failed cleanup leaves notifications behind, never stops the sync.
  static Future<void> _safely(String accountId, Future<void> Function() clean) async {
    try {
      await clean();
    } on Object catch (e) {
      // The type only: the error may quote the message.
      debugPrint('[notifiche] $accountId: cleanup failed, ${e.runtimeType}');
    }
  }
}
