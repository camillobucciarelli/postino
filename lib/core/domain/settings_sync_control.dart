import 'result.dart';
import 'sync_status.dart';

/// What the UI may ask of the sync of the Impostazioni di Postino (ADR 0016, 0019): its outcome, a cycle now, and the
/// Chiave di sincronizzazione through the Abbinamento.
abstract interface class SettingsSyncControl() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The last cycle's outcome by Account di sincronizzazione (#317): now, then at every change. In memory only. A
  /// device to pair fails with [SyncNotPairedFailure] or [SyncKeyInvalidFailure].
  Stream<Map<String, SyncStatus>> watchStatus();

  /// Runs a cycle now («Riprova», back in foreground); completes after it.
  Future<void> syncNow();

  /// The codice di abbinamento of this device's key, for «Abbina un altro dispositivo»; null before it has one.
  Future<String?> pairingCode();

  /// Pairs this device with [code]: its key is kept only once it opened the file on Drive as it is now. A malformed
  /// code, or one that does not open it, is a [PairingCodeFailure]; no sealed file a [NothingToPairFailure].
  Future<Result<void>> pair(String code);

  /// «Rigenera la chiave»: a new key, the file merged first when it reads, then written sealed with it; a file that
  /// does not read is overwritten with the voci of this device. The other devices must be paired again.
  Future<Result<void>> regenerateKey();
}
