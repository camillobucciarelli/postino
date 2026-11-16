import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'qr_camera.dart';

/// «Inquadra il QR» in «Abbina questo dispositivo» (#321): the camera's picture, square, with [error] under it while it
/// keeps scanning. Without a camera or its permission it says why in the picture's place: the dialog's «Digita il
/// codice» stays there.
class const PairingScanArea({super.key, required final ValueChanged<String> onCode, final String? error})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
        PostinoSelectable(
          child: Text(t.syncPairScanBody, style: PostinoText.body.copyWith(color: c.ink)),
        ),
        Semantics(
          label: t.syncPairScanPreview,
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PostinoRadius.md),
            child: AspectRatio(
              aspectRatio: 1,
              child: GetIt.I<QrCamera>().preview(
                onCode: onCode,
                problem: (problem) => ColoredBox(
                  color: c.surfaceRaised,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(PostinoSpacing.s4),
                      child: PostinoBanner(
                        key: const ValueKey('pairing-scan-problem'),
                        tone: PostinoBannerTone.warning,
                        title: problem == QrCameraProblem.denied ? t.syncPairCameraDenied : t.syncPairCameraUnavailable,
                        spaced: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error != null)
          PostinoBanner(
            key: const ValueKey('pairing-scan-error'),
            tone: PostinoBannerTone.danger,
            title: error!,
            spaced: false,
          ),
      ],
    );
  }
}
