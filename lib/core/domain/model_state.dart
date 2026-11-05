import 'result.dart';

/// Where an on-device model stands; sealed so `switch` stays exhaustive.
sealed class const ModelState() {
  /// Costruttore delle varianti.
  this;
}

/// Not on the device: never downloaded, deleted, or its download cancelled.
final class const ModelAbsent() extends ModelState {
  /// Crea lo stato.
  this;
}

/// Not on Wi-Fi: the download waits for the user to confirm, showing [sizeBytes].
final class const ModelAwaitingConfirmation(
  /// La dimensione del download da confermare, in byte.
  final int sizeBytes,
) extends ModelState {
  /// Crea lo stato con la dimensione da mostrare.
  this;
}

/// Downloading: [receivedBytes] of [totalBytes] so far.
final class const ModelDownloading(
  /// I byte già ricevuti.
  final int receivedBytes,

  /// I byte attesi in tutto.
  final int totalBytes,
) extends ModelState {
  /// Crea lo stato di avanzamento.
  this;

  /// From 0 to 1.
  double get progress => totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);
}

/// On the device, its hash checked, at [path].
final class const ModelReady(
  /// Il percorso del file del modello, da dare al runtime.
  final String path,
) extends ModelState {
  /// Crea lo stato con il percorso del file.
  this;
}

/// The last download failed with [failure]: [IntegrityFailure] for a file that did not match its hash.
final class const ModelFailed(
  /// Il motivo del fallimento.
  final Failure failure,
) extends ModelState {
  /// Crea lo stato con il motivo del fallimento.
  this;
}
