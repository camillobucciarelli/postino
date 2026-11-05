import 'dart:async';

import 'package:postino/core/domain/model_descriptor.dart';
import 'package:postino/core/domain/model_manager.dart';
import 'package:postino/core/domain/model_state.dart';
import 'package:postino/core/domain/result.dart';

/// A model manager in memory: a download is two steps, then ready at `/models/<file>`. The test sets the network
/// ([onWifi]), makes the next download fail ([failNext]) or moves a model by hand ([emit]).
class FakeModelManager() implements ModelManager {
  final _states = <String, ModelState>{};
  final _changes = StreamController<(String, ModelState)>.broadcast(sync: true);

  /// Whether the network is Wi-Fi: off it, [activate] waits for confirmation.
  bool onWifi = true;

  /// The next download stops halfway with a lost connection; reset when it fails.
  bool failNext = false;

  /// Every call, as `activate`, `download`, … with the model id.
  final calls = <String>[];

  ModelState stateOf(ModelDescriptor model) => _states[model.id] ?? const ModelAbsent();

  void emit(ModelDescriptor model, ModelState state) => _changes.add((model.id, _states[model.id] = state));

  @override
  Stream<ModelState> watch(ModelDescriptor model) => Stream.multi((out) {
    // Synchronous, as the test reads the state right after each step.
    out.addSync(stateOf(model));
    final changes = _changes.stream.where((c) => c.$1 == model.id).listen((c) => out.addSync(c.$2));
    out.onCancel = changes.cancel;
  });

  @override
  Future<void> activate(ModelDescriptor model) async {
    calls.add('activate ${model.id}');
    await Future<void>.delayed(Duration.zero);
    if (stateOf(model) case ModelAbsent() || ModelFailed()) {
      if (onWifi) return _download(model);
      emit(model, ModelAwaitingConfirmation(model.sizeBytes));
    }
  }

  @override
  Future<void> download(ModelDescriptor model) async {
    calls.add('download ${model.id}');
    if (stateOf(model) case ModelDownloading() || ModelReady()) return;
    await _download(model);
  }

  Future<void> _download(ModelDescriptor model) async {
    emit(model, ModelDownloading(0, model.sizeBytes));
    await Future<void>.delayed(Duration.zero);
    emit(model, ModelDownloading(model.sizeBytes ~/ 2, model.sizeBytes));
    await Future<void>.delayed(Duration.zero);
    if (failNext) {
      failNext = false;
      return emit(model, const ModelFailed(OfflineFailure()));
    }
    emit(model, ModelReady('/models/${model.fileName}'));
  }

  @override
  Future<void> cancel(ModelDescriptor model) async {
    calls.add('cancel ${model.id}');
    if (stateOf(model) is! ModelReady) emit(model, const ModelAbsent());
  }

  @override
  Future<int> sizeOnDisk(ModelDescriptor model) async => stateOf(model) is ModelReady ? model.sizeBytes : 0;

  @override
  Future<void> delete(ModelDescriptor model) async {
    calls.add('delete ${model.id}');
    emit(model, const ModelAbsent());
  }
}
