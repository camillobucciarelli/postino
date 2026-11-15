import 'dart:async';

import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_backend.dart';

/// The file of the Impostazioni di Postino in memory: share one between devices to sync them.
class FakeSettingsBackend() implements SettingsBackend {
  /// Il contenuto del file; null finché non esiste.
  String? file;

  /// While set, every read fails with it: offline, a missing scope.
  Failure? readFailure;

  /// While set, every read throws it: an error no [Failure] stands for.
  Object? readThrows;

  /// While set, every write fails with it, after being attempted.
  Failure? writeFailure;

  /// While set, reads wait for it to complete: a cycle held in flight.
  Completer<void>? readGate;

  var reads = 0;
  var writes = 0;
  var writeAttempts = 0;

  /// Reads in flight now, and the most there ever were at once.
  var _inFlight = 0;
  var maxInFlight = 0;

  @override
  Future<Result<String?>> read() async {
    reads++;
    maxInFlight = ++_inFlight > maxInFlight ? _inFlight : maxInFlight;
    try {
      await readGate?.future;
      if (readThrows case final e?) throw e;
      if (readFailure case final f?) return Err(f);
      return Ok(file);
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<Result<void>> write(String json) async {
    writeAttempts++;
    if (writeFailure case final f?) return Err(f);
    writes++;
    file = json;
    return const Ok(null);
  }
}
