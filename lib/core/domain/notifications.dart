import 'mail_notification.dart';
import 'new_mail_summary.dart';
import 'notification_target.dart';

/// The OS's notifications (#39): flutter_local_notifications in core/data, a fake in tests. Grouped per Account
/// (#210) where the OS groups them.
abstract interface class Notifications() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Prepares the notifications, in `main()` before `runApp`: [channelName] names them in the system settings
  /// (Android), [openLabel] is their default action (Linux), [newMessages] the text of a [NewMailSummary] of that
  /// many. Returns what the notification that launched the app opens (cold start), null otherwise.
  Future<NotificationTarget?> start({
    required String channelName,
    required String openLabel,
    required String Function(int count) newMessages,
  });

  /// Shows [notification], in place of the one of its Conversazione; a tap on it comes back through [taps], or
  /// through [start] when it launches the app.
  Future<void> show(MailNotification notification);

  /// Shows [summary] in place of every notification of its Account.
  Future<void> showSummary(NewMailSummary summary);

  /// Removes the notifications of [targets] that are shown: a Conversazione's, or an Account's summary.
  Future<void> cancel(List<NotificationTarget> targets);

  /// The taps on a notification while the app runs.
  Stream<NotificationTarget> get taps;

  /// True when the OS should still be asked to allow notifications (iOS, macOS, Android 13+).
  Future<bool> permissionNeeded();

  /// Asks the OS to allow notifications; true when allowed.
  Future<bool> requestPermission();
}
