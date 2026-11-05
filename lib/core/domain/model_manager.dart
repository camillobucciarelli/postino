import 'model_descriptor.dart';
import 'model_state.dart';

/// Downloads, checks and deletes the models that run on the device (ADR 0015, #108); one per [ModelDescriptor].
/// The real one in core/data, a network and a file system in memory in tests.
abstract interface class ModelManager() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The [model]'s state now, then each time it changes.
  Stream<ModelState> watch(ModelDescriptor model);

  /// First activation: on Wi-Fi the download starts at once; on any other network, or one that cannot be told,
  /// the state becomes [ModelAwaitingConfirmation] until [download]. Nothing if the model is there or on its way.
  /// Completes when the download ends, whatever its outcome.
  Future<void> activate(ModelDescriptor model);

  /// Downloads [model] on any network: the user's confirmation, or the retry after [ModelFailed].
  /// Completes when the download ends, whatever its outcome; never throws, a failure is a [ModelFailed].
  Future<void> download(ModelDescriptor model);

  /// Stops the download and removes what it wrote, or drops the pending confirmation: back to [ModelAbsent].
  Future<void> cancel(ModelDescriptor model);

  /// The bytes [model] takes on disk now, a partial download included.
  Future<int> sizeOnDisk(ModelDescriptor model);

  /// Removes [model] from the device, freeing its space.
  Future<void> delete(ModelDescriptor model);
}
