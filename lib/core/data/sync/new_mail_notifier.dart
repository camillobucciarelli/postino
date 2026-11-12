import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/account.dart';
import '../../domain/mail_notification.dart';
import '../../domain/message.dart';
import '../../domain/new_mail_summary.dart';
import '../../domain/notifications.dart';
import '../../domain/open_conversation.dart';
import '../mail_store.dart';

/// Notifies the new mail an incremental sync brings (#39): the unread messages in the inbox that were not in the
/// database before it, except those of the Conversazione on screen. The initial sync never notifies. One
/// notification per Conversazione in the Account's group; past [summaryThreshold] messages one summary instead (#210).
@lazySingleton
class NewMailNotifier(final MailStore _store, final Notifications _notifications, final OpenConversation _open) {
  /// The messages of [messages] to notify; read before the batch is applied, which makes them all known.
  Future<List<Message>> fresh(String accountId, List<Message> messages) async => [
    for (final m in messages)
      if (m.labelIds.contains(inboxLabelId) && !m.isRead && !await _store.hasMessage(accountId, m.id)) m,
  ];

  /// Shows a notification for the newest of [messages] (from [fresh]) in each Conversazione, except the one on screen;
  /// more than [summaryThreshold] of them, one «N nuovi messaggi» for the Account instead. One per Conversazione: the
  /// batch comes in no order (Gmail fills it as its fetches complete), and a later notification replaces the earlier
  /// one of its Conversazione.
  Future<void> notify(Account account, List<Message> messages) async {
    final accountId = account.id;
    final newest = <String, Message>{};
    var count = 0;
    for (final m in messages) {
      if (_open.isOpen((accountId: accountId, conversationId: m.conversationId))) continue;
      count++;
      newest.update(m.conversationId, (seen) => _newer(seen, m), ifAbsent: () => m);
    }
    if (count > summaryThreshold) {
      return _safely(
        accountId,
        () => _notifications.showSummary(
          NewMailSummary(accountId: accountId, accountAddress: account.address, count: count),
        ),
      );
    }
    for (final m in newest.values) {
      await _safely(
        accountId,
        () => _notifications.show(
          MailNotification(
            conversation: (accountId: accountId, conversationId: m.conversationId),
            accountAddress: account.address,
            sender: switch (m.fromName) {
              final name? when name.isNotEmpty => name,
              _ => m.from,
            },
            subject: m.subject,
            preview: m.snippet,
          ),
        ),
      );
    }
  }

  /// A notification the OS refuses does not stop the next ones nor the sync.
  static Future<void> _safely(String accountId, Future<void> Function() show) async {
    try {
      await show();
    } on Object catch (e) {
      // The type only: the error may quote the message.
      debugPrint('[notifiche] $accountId: show failed, ${e.runtimeType}');
    }
  }

  /// The later by date; on the same date the greater Provider id, so the choice never depends on the batch order.
  static Message _newer(Message a, Message b) => switch (a.date.compareTo(b.date)) {
    > 0 => a,
    < 0 => b,
    _ => a.id.compareTo(b.id) >= 0 ? a : b,
  };
}
