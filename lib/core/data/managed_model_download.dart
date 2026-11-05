import 'dart:async';

import '../domain/model_descriptor.dart';
import '../domain/model_download.dart';
import '../domain/model_download_state.dart';
import '../domain/model_manager.dart';
import '../domain/model_state.dart';

/// The download of the Etichettatura automatica model (#135): [_model] through [_manager], in the states the UI
/// follows. Two are the UI's own: preparing, while the first activation asks the network, and waiting for Wi-Fi,
/// a confirmation the user put off.
class ManagedModelDownload(final ModelManager _manager, final ModelDescriptor _model) implements ModelDownload {
  this {
    // ignore: cancel_subscriptions, lives as long as the app (a singleton).
    _manager.watch(_model).listen((state) {
      _managed = state;
      _update();
    });
  }

  final _changes = StreamController<ModelDownloadState>.broadcast(sync: true);
  ModelState _managed = const ModelAbsent();
  ModelDownloadState _state = const ModelDownloadAbsent();

  /// The first activation is asking the network.
  var _preparing = false;

  /// «Aspetta il Wi-Fi» on the confirmation.
  var _waiting = false;

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
    _preparing = true;
    _update();
    try {
      await _manager.activate(_model);
    } finally {
      _preparing = false;
      _update();
    }
  }

  @override
  Future<void> download() async {
    if (_state case ModelDownloadInProgress() || ModelDownloadReady() || ModelDownloadPreparing()) return;
    _waiting = false;
    await _manager.download(_model);
  }

  @override
  void waitForWifi() {
    // ponytail: never leaves by itself when Wi-Fi comes back; «Scarica ora» downloads. Listen to the network
    // (Connectivity.onChanged) if users wait for long.
    if (_state is! ModelDownloadAwaitingConfirmation) return;
    _waiting = true;
    _update();
  }

  void _update() {
    // A confirmation put off counts for that confirmation only.
    if (_managed is! ModelAwaitingConfirmation) _waiting = false;
    final next = switch (_managed) {
      ModelAbsent() when _preparing => const ModelDownloadPreparing(),
      ModelAbsent() => const ModelDownloadAbsent(),
      ModelAwaitingConfirmation(:final sizeBytes) when _waiting => ModelDownloadWaitingForWifi(sizeBytes),
      ModelAwaitingConfirmation(:final sizeBytes) => ModelDownloadAwaitingConfirmation(sizeBytes),
      ModelDownloading(:final receivedBytes, :final totalBytes) => ModelDownloadInProgress(receivedBytes, totalBytes),
      ModelFailed(:final failure) => ModelDownloadFailed(failure),
      ModelReady() => const ModelDownloadReady(),
    };
    // The flags change the state only now and then: what did not change is not news.
    if (next.runtimeType == _state.runtimeType && next is! ModelDownloadInProgress) return;
    _changes.add(_state = next);
  }
}
