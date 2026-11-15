import 'sync_status.dart';

/// What the UI may ask of the sync of the Impostazioni di Postino (ADR 0016): its outcome and a cycle now.
abstract interface class SettingsSyncControl() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The last cycle's outcome by Account di sincronizzazione (#317): now, then at every change. In memory only.
  Stream<Map<String, SyncStatus>> watchStatus();

  /// Runs a cycle now («Riprova», back in foreground); completes after it.
  Future<void> syncNow();
}
