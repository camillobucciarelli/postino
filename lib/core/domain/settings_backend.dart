import 'result.dart';

/// Where the file of the Impostazioni di Postino lives (ADR 0016): Drive today, an export/import file tomorrow.
abstract interface class SettingsBackend() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The file as JSON text; null when it does not exist yet.
  Future<Result<String?>> read();

  /// Replaces the file with [json], creating it if needed.
  Future<Result<void>> write(String json);
}
