import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../design_system/design_system.dart';
import '../../i18n/strings.g.dart';
import '../domain/model_download.dart';
import '../domain/model_download_state.dart';
import '../domain/result.dart';
import 'model_download_confirm.dart';
import 'model_download_progress.dart';

/// Where the model download stands (#107), as a Banner: info while preparing, waiting or downloading, danger
/// with «Riprova» when it failed. The same one tops the Posta lists and the page of the Etichette automatiche
/// ([showReady]: there «Modello pronto» stays; on the lists the banner goes away when it is ready).
/// Nothing while the model is absent. It opens and closes, and one stage fades into the next (PostinoReveal, #283).
class const ModelDownloadBanner({super.key, final bool showReady = false, final bool spaced = true})
    extends StatefulWidget {
  @override
  State<ModelDownloadBanner> createState() => _ModelDownloadBannerState();
}

class _ModelDownloadBannerState() extends State<ModelDownloadBanner> {
  final _model = GetIt.I<ModelDownload>();

  /// One subscription for the life of the widget: a new stream at every build would resubscribe, and the state
  /// it replays would rebuild again.
  late final _states = _model.watch();

  bool get showReady => widget.showReady;
  bool get spaced => widget.spaced;

  @override
  Widget build(BuildContext context) => StreamBuilder<ModelDownloadState>(
    stream: _states,
    initialData: _model.state,
    builder: (context, snapshot) => PostinoReveal(
      // Same stage, same banner: the bar moves on in place. Waiting for a yes or for the Wi-Fi look the same.
      contentKey: switch (snapshot.requireData) {
        ModelDownloadAwaitingConfirmation() => ModelDownloadWaitingForWifi,
        final s => s.runtimeType,
      },
      child: _banner(context, snapshot.requireData),
    ),
  );

  Widget? _banner(BuildContext context, ModelDownloadState state) {
    final model = _model;
    final t = context.t.etichetteAutomatiche.model;
    return switch (state) {
      ModelDownloadAbsent() => null,
      ModelDownloadPreparing() => PostinoBanner(
        key: const ValueKey('model-banner'),
        tone: PostinoBannerTone.info,
        spaced: spaced,
        title: t.preparing,
        leading: PostinoSpinner(label: t.preparing),
      ),
      ModelDownloadAwaitingConfirmation(:final sizeBytes) ||
      ModelDownloadWaitingForWifi(:final sizeBytes) => PostinoBanner(
        key: const ValueKey('model-banner'),
        tone: PostinoBannerTone.info,
        spaced: spaced,
        icon: PostinoIcons.download,
        title: t.waitingTitle,
        message: t.waitingBody(size: megabytes(sizeBytes)),
        actionLabel: t.downloadNow,
        onAction: () => confirmModelDownload(context, sizeBytes),
      ),
      ModelDownloadInProgress(:final receivedBytes, :final totalBytes) => _progress(context, receivedBytes, totalBytes),
      ModelDownloadFailed(:final failure) => PostinoBanner(
        key: const ValueKey('model-banner'),
        tone: PostinoBannerTone.danger,
        spaced: spaced,
        title: t.failedTitle,
        message: failure is OfflineFailure ? t.failedOffline : t.failedOther,
        actionLabel: t.retry,
        onAction: model.download,
      ),
      ModelDownloadReady() =>
        showReady
            ? PostinoBanner(
                key: const ValueKey('model-banner'),
                tone: PostinoBannerTone.info,
                spaced: spaced,
                icon: PostinoIcons.check,
                title: t.ready,
                message: t.readyBody,
              )
            : null,
    };
  }

  Widget _progress(BuildContext context, int received, int total) {
    final t = context.t.etichetteAutomatiche.model;
    final p = downloadProgress(received, total);
    return PostinoBanner(
      key: const ValueKey('model-banner'),
      tone: PostinoBannerTone.info,
      spaced: spaced,
      icon: PostinoIcons.download,
      title: t.downloading,
      // The bar speaks in steps of 25%; the exact figures are for the eyes, out of the live region's reading.
      progress: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: PostinoSpacing.s1,
        children: [
          PostinoProgressBar(label: t.downloading, value: total <= 0 ? null : received / total),
          ExcludeSemantics(
            child: Text(
              t.progress(received: p.received, total: p.total, percent: p.percent),
              style: PostinoText.meta.copyWith(color: context.pc.ink),
            ),
          ),
        ],
      ),
    );
  }
}
