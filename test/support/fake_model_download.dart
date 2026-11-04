import 'dart:async';

import 'package:postino/core/domain/model_download.dart';
import 'package:postino/core/domain/model_download_state.dart';

/// A model download the test moves by hand: [emit] a state, then look at the screen.
class FakeModelDownload() implements ModelDownload {
  final _changes = StreamController<ModelDownloadState>.broadcast(sync: true);
  ModelDownloadState _state = const ModelDownloadAbsent();

  /// How many times each action was called.
  int activations = 0;
  int downloads = 0;
  int waits = 0;

  void emit(ModelDownloadState state) => _changes.add(_state = state);

  @override
  ModelDownloadState get state => _state;

  @override
  Stream<ModelDownloadState> watch() => Stream.multi((out) {
    out.add(_state);
    final sub = _changes.stream.listen(out.add);
    out.onCancel = sub.cancel;
  });

  @override
  Future<void> activate() async => activations++;

  @override
  Future<void> download() async => downloads++;

  @override
  void waitForWifi() => waits++;
}
