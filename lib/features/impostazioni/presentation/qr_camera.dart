import 'package:flutter/widgets.dart';

/// Why the camera shows no picture.
enum QrCameraProblem() {
  /// The permission to use it was refused.
  denied,

  /// There is no camera to use, or it failed to start.
  unavailable,
}

/// The camera that reads the QR of the Abbinamento (ADR 0019, #321); a fake in tests. The text it reads is the
/// codice di abbinamento, i.e. the key: it goes to [preview]'s `onCode` and nowhere else, never to a log.
abstract interface class QrCamera() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Whether this platform has a camera to scan with (iOS, Android, macOS); elsewhere the code is only typed.
  bool get available;

  /// The live picture of the camera: [onCode] with the text of each code it reads, as often as it reads it;
  /// [problem] drawn in its place when there is no picture.
  Widget preview({required ValueChanged<String> onCode, required Widget Function(QrCameraProblem) problem});
}
