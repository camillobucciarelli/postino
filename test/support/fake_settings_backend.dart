import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_backend.dart';

/// The file of the Impostazioni di Postino in memory: share one between devices to sync them.
class FakeSettingsBackend() implements SettingsBackend {
  /// Il contenuto del file; null finché non esiste.
  String? file;

  /// While set, every read and write fails with it: offline, a missing scope.
  Failure? failure;
  var reads = 0;
  var writes = 0;

  @override
  Future<Result<String?>> read() async {
    reads++;
    if (failure case final f?) return Err(f);
    return Ok(file);
  }

  @override
  Future<Result<void>> write(String json) async {
    if (failure case final f?) return Err(f);
    writes++;
    file = json;
    return const Ok(null);
  }
}
