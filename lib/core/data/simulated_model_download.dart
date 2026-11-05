import 'dart:async';

import 'package:injectable/injectable.dart';

import '../domain/model_download.dart';
import '../domain/model_download_state.dart';
import '../domain/network_type.dart';
import '../domain/result.dart';

/// A pretend model download (#107), until the real model manager (#108): preparing, then [steps] chunks of a
/// ~310 MB file [stepDelay] apart, then ready. Set [failNext] to make the next download fail halfway.
@LazySingleton(as: ModelDownload)
class SimulatedModelDownload(final NetworkType _network) implements ModelDownload {
  /// The GGUF Q8_0 of ADR 0015, in bytes.
  static const sizeBytes = 310 * 1000 * 1000;

  /// Pause between two states; zero in tests.
  Duration stepDelay = const Duration(milliseconds: 400);

  /// Chunks of the download.
  int steps = 10;

  /// The next download stops halfway with a lost connection; reset when it fails.
  bool failNext = false;

  final _changes = StreamController<ModelDownloadState>.broadcast(sync: true);
  ModelDownloadState _state = const ModelDownloadAbsent();

  @override
  ModelDownloadState get state => _state;

  @override
  Stream<ModelDownloadState> watch() => Stream.multi((out) {
    // Synchronous: no change can slip between the state now and the subscription.
    out.add(_state);
    final changes = _changes.stream.listen(out.add);
    out.onCancel = changes.cancel;
  });

  @override
  Future<void> activate() async {
    if (_state is! ModelDownloadAbsent) return;
    _emit(const ModelDownloadPreparing());
    await Future<void>.delayed(stepDelay);
    if (await _network.isOnWifi()) {
      await _download();
    } else {
      _emit(const ModelDownloadAwaitingConfirmation(sizeBytes));
    }
  }

  @override
  Future<void> download() async {
    if (_state case ModelDownloadInProgress() || ModelDownloadReady() || ModelDownloadPreparing()) return;
    await _download();
  }

  @override
  void waitForWifi() {
    // ponytail: never leaves by itself when Wi-Fi comes back; the real manager (#108) listens to the network.
    if (_state is ModelDownloadAwaitingConfirmation) _emit(const ModelDownloadWaitingForWifi(sizeBytes));
  }

  Future<void> _download() async {
    for (var i = 0; i < steps; i++) {
      _emit(ModelDownloadInProgress(sizeBytes * i ~/ steps, sizeBytes));
      await Future<void>.delayed(stepDelay);
      if (failNext && i >= steps ~/ 2) {
        failNext = false;
        _emit(const ModelDownloadFailed(OfflineFailure()));
        return;
      }
    }
    _emit(const ModelDownloadReady());
  }

  void _emit(ModelDownloadState state) => _changes.add(_state = state);
}
