import 'result.dart';

/// Where the file of the Impostazioni di Postino lives (ADR 0016): Drive today, an export/import file tomorrow. It
/// moves the file as text and never sees the Chiave di sincronizzazione (ADR 0019): the sealing is `SettingsSync`'s.
abstract interface class SettingsBackend() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Every copy of the file as text, oldest first: none when it does not exist yet, more than one when two devices
  /// created it at once.
  Future<Result<List<String>>> read();

  /// Replaces the oldest copy the last [read] found with [text], creating the file if there was none.
  Future<Result<void>> write(String text);

  /// Deletes every copy but the oldest that the last [read] found.
  Future<Result<void>> dropDuplicates();
}
