/// The texts of the fixed notification of the Notifiche immediate, from the app's i18n: `channel` names it in the
/// system settings.
typedef ListeningNotice = ({String channel, String title, String text});

/// Le Notifiche immediate (#214): on Android a foreground service that keeps Postino's sync alive with the app
/// closed, at the price of a fixed notification and of the esclusione dall'ottimizzazione batteria. The real one in
/// core/data, a fake in tests.
abstract interface class ImmediateNotifications() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// False everywhere but Android.
  bool get supported;

  /// Starts the service with its fixed notification [notice]; while it runs, refreshes the notification. Throws when
  /// the OS refuses.
  Future<void> start(ListeningNotice notice);

  /// Stops the service: the periodic check (#212) goes on alone.
  Future<void> stop();

  /// Asks the OS to exclude Postino from the battery optimization (its own dialog), unless it already is.
  Future<void> requestBatteryExemption();

  /// The fixed notification tapped: the Posta unificata opens.
  Stream<void> get opened;
}
