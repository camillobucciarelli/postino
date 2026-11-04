import 'mail_notification.dart';

/// The OS's notifications (#39): flutter_local_notifications in core/data, a fake in tests.
abstract interface class Notifications() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Prepares the notifications, in `main()` before `runApp`: [channelName] names them in the system settings
  /// (Android), [openLabel] is their default action (Linux). Returns the Conversazione whose notification launched
  /// the app (cold start), null otherwise.
  Future<ConversationKey?> start({required String channelName, required String openLabel});

  /// Shows [notification]; a tap on it comes back through [taps], or through [start] when it launches the app.
  Future<void> show(MailNotification notification);

  /// The taps on a notification while the app runs.
  Stream<ConversationKey> get taps;

  /// True when the OS should still be asked to allow notifications (iOS, macOS, Android 13+).
  Future<bool> permissionNeeded();

  /// Asks the OS to allow notifications; true when allowed.
  Future<bool> requestPermission();
}
