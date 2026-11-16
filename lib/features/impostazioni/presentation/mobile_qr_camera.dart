import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_camera.dart';

/// [QrCamera] on `mobile_scanner`: AVFoundation and Vision on iOS and macOS, ML Kit from Google Play Services on
/// Android (unbundled, see `android/gradle.properties`). The plugin asks the permission when the preview starts.
/// Here and not in core/data: the port hands out a widget, which core/domain cannot name.
@LazySingleton(as: QrCamera, env: [Environment.prod])
class MobileQrCamera() implements QrCamera {
  @override
  bool get available =>
      !kIsWeb &&
      const {TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS}.contains(defaultTargetPlatform);

  @override
  Widget preview({required ValueChanged<String> onCode, required Widget Function(QrCameraProblem) problem}) =>
      _Preview(onCode: onCode, problem: problem);
}

/// The plugin's preview; a reader that fails while the picture runs (Android without Google Play Services, or its
/// ML Kit module not downloaded yet) shows [problem] too, rather than a picture that never reads anything.
class const _Preview({
  required final ValueChanged<String> onCode,
  required final Widget Function(QrCameraProblem) problem,
}) extends StatefulWidget {
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState() extends State<_Preview> {
  var _failed = false;

  @override
  Widget build(BuildContext context) => _failed
      ? widget.problem(QrCameraProblem.unavailable)
      : MobileScanner(
          onDetect: (capture) {
            for (final code in capture.barcodes) {
              if (code.rawValue case final text?) widget.onCode(text);
            }
          },
          onDetectError: (_, _) {
            if (mounted && !_failed) setState(() => _failed = true);
          },
          errorBuilder: (_, error) => widget.problem(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? QrCameraProblem.denied
                : QrCameraProblem.unavailable,
          ),
        );
}
