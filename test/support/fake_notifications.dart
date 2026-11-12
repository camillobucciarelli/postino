import 'dart:async';

import 'package:postino/core/domain/mail_notification.dart';
import 'package:postino/core/domain/new_mail_summary.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/core/domain/notifications.dart';

/// Records every notification instead of showing it; [tap] stands for a tap on one while the app runs. [visible] is
/// what the OS would show now: per Account (its group), the notifications by what they open.
class FakeNotifications() implements Notifications {
  /// Every notification shown, in order.
  final shown = <MailNotification>[];

  /// Every summary shown, in order.
  final summaries = <NewMailSummary>[];

  /// What the OS shows now, grouped per Account.
  final visible = <String, Set<NotificationTarget>>{};

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
      for (final t in group)
        if (t case ConversationTarget(:final conversation)) conversation.conversationId,
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
    required void Function(NotificationActionTap tap) onAction,
  }) async {
    this.onAction = onAction;
    return launch;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<void> show(MailNotification notification) async {
    if (failures > 0) {
      failures--;
      throw StateError('notification refused');
    }
    shown.add(notification);
    (visible[notification.conversation.accountId] ??= {}).add(ConversationTarget(notification.conversation));
  }

  @override
  Future<void> showSummary(NewMailSummary summary) async {
    summaries.add(summary);
    visible[summary.accountId] = {AccountTarget(summary.accountId)};
  }

  @override
  Future<void> cancel(List<NotificationTarget> targets) async {
    for (final t in targets) {
      visible[t.accountId]?.remove(t);
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
