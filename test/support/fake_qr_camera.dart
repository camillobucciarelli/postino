import 'package:flutter/widgets.dart';
import 'package:postino/features/impostazioni/presentation/qr_camera.dart';

/// The camera of «Inquadra il QR», without a camera: a test makes it [read] a text, or show no picture ([failure]).
class FakeQrCamera() implements QrCamera {
  @override
  var available = true;

  /// While set, the camera shows no picture, for this reason.
  QrCameraProblem? failure;

  late ValueChanged<String> _onCode;

  /// The camera reads [text] in the picture on screen.
  void read(String text) => _onCode(text);

  @override
  Widget preview({required ValueChanged<String> onCode, required Widget Function(QrCameraProblem) problem}) {
    _onCode = onCode;
    return failure == null ? const SizedBox.expand(key: ValueKey('fake-qr-camera')) : problem(failure!);
  }
}
