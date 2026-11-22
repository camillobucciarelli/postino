import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/account.dart';
import '../../domain/mail_notification.dart';
import '../../domain/message.dart';
import '../../domain/notification_action.dart';
import '../../domain/notifications.dart';
import '../../domain/open_conversation.dart';
import '../../domain/settings_repository.dart';
import '../mail_store.dart';

/// The OS answers a notification call within this: the sync waits for them, and a call that never returns would hold
/// the Account's queue for good.
const notificationWithin = Duration(seconds: 15);

/// Notifies the new mail an incremental sync brings (#39): the unread messages in the inbox that were not in the
/// database before it, except those of the Conversazione on screen. The initial sync never notifies. One notification
/// per message (#238), in its Account's group.
@lazySingleton
class NewMailNotifier(
  final MailStore _store,
  final Notifications _notifications,
  final OpenConversation _open,
  final SettingsRepository _settings,
) {
  /// The messages of [messages] to notify; read before the batch is applied, which makes them all known.
  Future<List<Message>> fresh(String accountId, List<Message> messages) async => [
    for (final m in messages)
      if (m.labelIds.contains(inboxLabelId) && !m.isRead && !await _store.hasMessage(accountId, m.id)) m,
  ];

  /// Shows a notification for each of [messages] (from [fresh]) but those of the Conversazione on screen, oldest
  /// first: the batch comes in no order (Gmail fills it as its fetches complete), and the newest goes on top. The
  /// Account's summary goes first, once: Android sheds the updates that follow a burst of posts.
  Future<void> notify(Account account, List<Message> messages) async {
    final accountId = account.id;
    final notified = [
      for (final m in messages)
        if (!_open.isOpen((accountId: accountId, conversationId: m.conversationId))) m,
    ]..sort(_byDate);
    if (notified.isEmpty) return;
    final actions = buttonsOf(await _settings.notificationActions());
    await _safely(
      accountId,
      () => _notifications.summarize(accountId, account.address, [for (final m in notified) m.id]),
    );
    for (final m in notified) {
      await _safely(
        accountId,
        () => _notifications.show(
          MailNotification(
            conversation: (accountId: accountId, conversationId: m.conversationId),
            messageId: m.id,
            accountAddress: account.address,
            sender: switch (m.fromName) {
              final name? when name.isNotEmpty => name,
              _ => m.from,
            },
            subject: m.subject,
            preview: m.snippet,
            actions: actions,
          ),
        ),
      );
    }
  }

  /// A notification the OS refuses, or never answers about, does not stop the next ones nor the sync.
  static Future<void> _safely(String accountId, Future<void> Function() post) async {
    try {
      await post().timeout(notificationWithin);
    } on Object catch (e) {
      // The type only: the error may quote the message.
      debugPrint('[notifiche] $accountId: show failed, ${e.runtimeType}');
    }
  }

  /// By date; on the same date by Provider id, so the order never depends on the batch's.
  static int _byDate(Message a, Message b) => switch (a.date.compareTo(b.date)) {
    0 => a.id.compareTo(b.id),
    final c => c,
  };
}
