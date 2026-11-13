import 'dart:async';

import 'package:postino/core/domain/mail_notification.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/core/domain/notifications.dart';

/// Records every notification instead of showing it; [tap] stands for a tap on one while the app runs. [visible] is
/// what the OS would show now: per Account (its group), the notifications by message, with the Conversazione they open.
class FakeNotifications() implements Notifications {
  /// Every notification shown, in order.
  final shown = <MailNotification>[];

  /// What the OS shows now, grouped per Account: message id → its Conversazione.
  final visible = <String, Map<String, ConversationKey>>{};

  /// The messages with a notification on screen, of every Account.
  Set<String> get visibleMessages => {for (final group in visible.values) ...group.keys};

  /// While set, [show] waits for it.
  Completer<void>? gate;

  /// How many of the next [show]s throw, as an OS refusing them would.
  int failures = 0;

  /// What [start] returns: what the notification that launched the app opens.
  NotificationTarget? launch;

  /// Whether the OS would still ask; [requests] counts the asks.
  bool needed = false;
  int requests = 0;

  final _taps = StreamController<NotificationTarget>.broadcast();

  /// A tap on the notification of [target] while the app runs.
  void tap(NotificationTarget target) => _taps.add(target);

  /// The Conversazioni with a notification on screen, of every Account.
  Set<String> get visibleConversations => {
    for (final group in visible.values)
      for (final c in group.values) c.conversationId,
  };

  /// What [start] was given to run a button tapped while the app runs.
  void Function(NotificationActionTap tap)? onAction;

  /// How many times the system settings were opened.
  int settingsOpened = 0;

  @override
  Future<NotificationTarget?> start({
    required String channelName,
    required String openLabel,
    required String Function(int count) newMessages,
    required String Function(NotificationAction action) actionLabel,
    required void Function(NotificationActionTap tap)? onAction,
  }) async {
    this.onAction = onAction;
    return launch;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<void> show(MailNotification notification) async {
    await gate?.future;
    if (failures > 0) {
      failures--;
      throw StateError('notification refused');
    }
    shown.add(notification);
    (visible[notification.conversation.accountId] ??= {})[notification.messageId] = notification.conversation;
  }

  /// Every [summarize], in order: the Account, the messages about to be shown, and how many were [shown] before it.
  final summarized = <(String, List<String>, int)>[];

  @override
  Future<void> summarize(String accountId, String accountAddress, List<String> messageIds) async =>
      summarized.add((accountId, messageIds, shown.length));

  @override
  Future<void> cancel(String accountId, Iterable<String> messageIds) async {
    for (final id in messageIds) {
      visible[accountId]?.remove(id);
    }
  }

  @override
  Stream<NotificationTarget> get taps => _taps.stream;

  @override
  Future<bool> permissionNeeded() async => needed;

  @override
  Future<bool> requestPermission() async {
    requests++;
    needed = !grants;
    return grants;
  }

  /// Whether the OS allows them when asked; false as after a refusal, when it no longer asks.
  bool grants = true;
}
