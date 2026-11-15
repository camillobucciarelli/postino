import 'dart:async';
import 'dart:convert';

import 'package:postino/core/data/sync/settings_envelope.dart';
import 'package:postino/core/data/sync/sync_key.dart';
import 'package:postino/core/data/sync/sync_key_store.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_backend.dart';

import 'fake_platform.dart';

/// The Chiave di sincronizzazione the devices of a test share: paired.
final testSyncKey = SyncKey.random();

/// A device's keychain with [key] in it, as pairing leaves it; none with [key] null.
SyncKeyStore keysWith(SyncKey? key, [FakeSecureStore? keychain]) {
  final store = keychain ?? FakeSecureStore();
  if (key != null) {
    store.values
      ..[SyncKeyStore.name] = key.encode()
      ..['${SyncKeyStore.name}.device_only'] = '1';
  }
  return SyncKeyStore(store);
}

/// [doc] as a device with [key] writes it.
String sealedWith(Map<String, Object?> doc, [SyncKey? key]) => sealSettings(jsonEncode(doc), key ?? testSyncKey);

/// The file of the Impostazioni di Postino in memory: share one between devices to sync them.
class FakeSettingsBackend() implements SettingsBackend {
  /// Il contenuto del file; null finché non esiste.
  String? file;

  /// Copies after [file], from devices that created it at once: read after it, oldest first.
  List<String> duplicates = [];

  var drops = 0;

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
  Future<Result<List<String>>> read() async {
    reads++;
    maxInFlight = ++_inFlight > maxInFlight ? _inFlight : maxInFlight;
    try {
      await readGate?.future;
      if (readThrows case final e?) throw e;
      if (readFailure case final f?) return Err(f);
      return Ok([?file, ...duplicates]);
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<Result<void>> write(String text) async {
    writeAttempts++;
    if (writeFailure case final f?) return Err(f);
    writes++;
    file = text;
    return const Ok(null);
  }

  /// The voci of the file, opened with [key] (the shared one by default); throws if it does not open.
  Map<String, Object?> entries([SyncKey? key]) {
    final opened = openSettings(file!, key ?? testSyncKey) as OpenedCopy;
    return (jsonDecode(opened.json) as Map<String, dynamic>)['entries'] as Map<String, Object?>;
  }

  @override
  Future<Result<void>> dropDuplicates() async {
    drops++;
    duplicates = [];
    return const Ok(null);
  }
}
