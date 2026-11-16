import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_camera.dart';

/// [QrCamera] on `mobile_scanner`: AVFoundation and Vision on iOS and macOS, ML Kit from Google Play Services on
/// Android (unbundled, see `android/gradle.properties`). The plugin asks the permission when the preview starts.
@LazySingleton(as: QrCamera, env: [Environment.prod])
class MobileQrCamera() implements QrCamera {
  @override
  bool get available =>
      !kIsWeb &&
      const {TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS}.contains(defaultTargetPlatform);

  @override
  Widget preview({required ValueChanged<String> onCode, required Widget Function(QrCameraProblem) problem}) =>
      MobileScanner(
        onDetect: (capture) {
          for (final code in capture.barcodes) {
            if (code.rawValue case final text?) onCode(text);
          }
        },
        errorBuilder: (_, error) => problem(
          error.errorCode == MobileScannerErrorCode.permissionDenied
              ? QrCameraProblem.denied
              : QrCameraProblem.unavailable,
        ),
      );
}
