import 'model_download_state.dart';

/// The download of the Etichettatura automatica model, as the UI follows it (#107): the page and the banner
/// read [watch], the switch and the dialogs call the actions. The real one over the model manager in core/data (#135).
abstract interface class ModelDownload() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The state now.
  ModelDownloadState get state;

  /// The state now, then each time it changes.
  Stream<ModelDownloadState> watch();

  /// First activation of an Etichetta automatica: on Wi-Fi the download starts at once, on any other network
  /// it waits in [ModelDownloadAwaitingConfirmation]. Nothing unless [ModelDownloadAbsent].
  /// Completes when the download ends, whatever its outcome.
  Future<void> activate();

  /// «Scarica ora» (the confirmation on cellular) and «Riprova»: downloads on any network.
  /// Completes when the download ends; never throws, a failure is a [ModelDownloadFailed].
  Future<void> download();

  /// «Aspetta il Wi-Fi» (or Esc on the confirmation): from [ModelDownloadAwaitingConfirmation]
  /// to [ModelDownloadWaitingForWifi].
  void waitForWifi();
}
