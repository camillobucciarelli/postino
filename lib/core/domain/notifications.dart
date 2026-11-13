import 'mail_notification.dart';
import 'notification_action.dart';
import 'notification_target.dart';

/// The OS's notifications (#39): flutter_local_notifications in core/data, a fake in tests. One per message (#238),
/// grouped per Account where the OS groups them.
abstract interface class Notifications() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Prepares the notifications, in `main()` before `runApp`: [channelName] names them in the system settings
  /// (Android), [openLabel] is their default action (Linux), [newMessages] the title of an Account's group summary of
  /// that many messages (Android), [actionLabel] the title of a button (#211). [onAction] runs a button tapped in this isolate: while the app
  /// runs, on every platform; the one that launched the app too. Null where this isolate is not the app's (a
  /// background task, #212): the buttons are not taken here. Returns what the notification that launched the app
  /// opens (cold start), null otherwise.
  Future<NotificationTarget?> start({
    required String channelName,
    required String openLabel,
    required String Function(int count) newMessages,
    required String Function(NotificationAction action) actionLabel,
    required void Function(NotificationActionTap tap)? onAction,
  });

  /// Shows [notification], in its Account's group; a tap on it comes back through [taps], or through [start] when it
  /// launches the app.
  Future<void> show(MailNotification notification);

  /// Removes the notifications of the messages [messageIds] of [accountId] that are shown; the group's summary
  /// follows (Android).
  Future<void> cancel(String accountId, Iterable<String> messageIds);

  /// The taps on a notification while the app runs.
  Stream<NotificationTarget> get taps;

  /// True when the OS should still be asked to allow notifications (iOS, macOS, Android 13+).
  Future<bool> permissionNeeded();

  /// Asks the OS to allow notifications; true when allowed.
  Future<bool> requestPermission();

  /// Opens Postino's notifications in the system settings (iOS, macOS, Android): where a refused permission is
  /// given back, since the OS asks only once.
  Future<void> openSystemSettings();
}
