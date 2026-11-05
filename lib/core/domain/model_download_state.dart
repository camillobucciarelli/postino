import 'result.dart';

/// Where the download of the Etichettatura automatica model stands (#107); sealed so `switch` stays exhaustive.
sealed class const ModelDownloadState() {
  /// Costruttore delle varianti.
  this;
}

/// Not on the device and not asked for: no Etichetta automatica activated yet.
final class const ModelDownloadAbsent() extends ModelDownloadState {
  /// Crea lo stato.
  this;
}

/// The first activation is getting ready (network check, metadata): an indeterminate spinner.
final class const ModelDownloadPreparing() extends ModelDownloadState {
  /// Crea lo stato.
  this;
}

/// Not on Wi-Fi: the download waits for the user to confirm, showing [sizeBytes].
final class const ModelDownloadAwaitingConfirmation(
  /// La dimensione del download da confermare, in byte.
  final int sizeBytes,
) extends ModelDownloadState {
  /// Crea lo stato con la dimensione da mostrare.
  this;
}

/// The user chose «Aspetta il Wi-Fi»: «Scarica ora» opens the confirmation again.
final class const ModelDownloadWaitingForWifi(
  /// La dimensione del download, in byte.
  final int sizeBytes,
) extends ModelDownloadState {
  /// Crea lo stato con la dimensione del download.
  this;
}

/// Downloading: [receivedBytes] of [totalBytes] so far.
final class const ModelDownloadInProgress(
  /// I byte già ricevuti.
  final int receivedBytes,

  /// I byte attesi in tutto.
  final int totalBytes,
) extends ModelDownloadState {
  /// Crea lo stato di avanzamento.
  this;
}

/// The last download failed with [failure] (e.g. [OfflineFailure]: connection lost); «Riprova» downloads again.
final class const ModelDownloadFailed(
  /// Il motivo del fallimento.
  final Failure failure,
) extends ModelDownloadState {
  /// Crea lo stato con il motivo del fallimento.
  this;
}

/// On the device: the Etichettatura automatica can start.
final class const ModelDownloadReady() extends ModelDownloadState {
  /// Crea lo stato.
  this;
}
