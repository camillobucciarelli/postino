import 'dart:async';

import 'package:postino/core/domain/mail_notification.dart';
import 'package:postino/core/domain/notifications.dart';

/// Records every notification instead of showing it; [tap] stands for a tap on one while the app runs.
class FakeNotifications() implements Notifications {
  /// Every notification shown, in order.
  final shown = <MailNotification>[];

  /// How many of the next [show]s throw, as an OS refusing them would.
  int failures = 0;

  /// What [start] returns: the Conversazione of the notification that launched the app.
  ConversationKey? launch;

  /// Whether the OS would still ask; [requests] counts the asks.
  bool needed = false;
  int requests = 0;

  final _taps = StreamController<ConversationKey>.broadcast();

  /// A tap on the notification of [key] while the app runs.
  void tap(ConversationKey key) => _taps.add(key);

  @override
  Future<ConversationKey?> start({required String channelName, required String openLabel}) async => launch;

  @override
  Future<void> show(MailNotification notification) async {
    if (failures > 0) {
      failures--;
      throw StateError('notification refused');
    }
    shown.add(notification);
  }

  @override
  Stream<ConversationKey> get taps => _taps.stream;

  @override
  Future<bool> permissionNeeded() async => needed;

  @override
  Future<bool> requestPermission() async {
    requests++;
    needed = false;
    return true;
  }
}
