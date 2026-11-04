import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/mail_notification.dart';
import '../../domain/message.dart';
import '../../domain/notifications.dart';
import '../../domain/open_conversation.dart';
import '../mail_store.dart';

/// Notifies the new mail an incremental sync brings (#39): the unread messages in the inbox that were not in the
/// database before it, except those of the Conversazione on screen. The initial sync never notifies.
// ponytail: one notification per Conversazione, its newest message; grouping and the summary past 10 are step 7.
@lazySingleton
class NewMailNotifier(final MailStore _store, final Notifications _notifications, final OpenConversation _open) {
  /// The messages of [messages] to notify; read before the batch is applied, which makes them all known.
  Future<List<Message>> fresh(String accountId, List<Message> messages) async => [
    for (final m in messages)
      if (m.labelIds.contains(inboxLabelId) && !m.isRead && !await _store.hasMessage(accountId, m.id)) m,
  ];

  /// Shows a notification for the newest of [messages] (from [fresh]) in each Conversazione, except the one on screen.
  /// One per Conversazione: the batch comes in no order (Gmail fills it as its fetches complete), and a later
  /// notification replaces the earlier one of its Conversazione.
  Future<void> notify(String accountId, List<Message> messages) async {
    final newest = <String, Message>{};
    for (final m in messages) {
      newest.update(m.conversationId, (seen) => _newer(seen, m), ifAbsent: () => m);
    }
    for (final m in newest.values) {
      final conversation = (accountId: accountId, conversationId: m.conversationId);
      if (_open.isOpen(conversation)) continue;
      try {
        await _notifications.show(
          MailNotification(
            conversation: conversation,
            sender: switch (m.fromName) {
              final name? when name.isNotEmpty => name,
              _ => m.from,
            },
            subject: m.subject,
            preview: m.snippet,
          ),
        );
      } on Object catch (e) {
        // The type only: the error may quote the message.
        debugPrint('[notifiche] $accountId: show failed, ${e.runtimeType}');
      }
    }
  }

  /// The later by date; on the same date the greater Provider id, so the choice never depends on the batch order.
  static Message _newer(Message a, Message b) => switch (a.date.compareTo(b.date)) {
    > 0 => a,
    < 0 => b,
    _ => a.id.compareTo(b.id) >= 0 ? a : b,
  };
}
