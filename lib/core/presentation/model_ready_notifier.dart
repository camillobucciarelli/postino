import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../design_system/design_system.dart';
import '../../i18n/strings.g.dart';
import '../domain/model_download.dart';
import '../domain/model_download_state.dart';
import '../domain/platform_services.dart' show Clock;

/// Shows «Etichette automatiche pronte» once, when the model becomes ready while the app is running (#107).
/// Mounted once above the Posta views, so two panes side by side do not show it twice.
class const ModelReadyNotifier({super.key, required final Widget child}) extends StatefulWidget {
  @override
  State<ModelReadyNotifier> createState() => _ModelReadyNotifierState();
}

class _ModelReadyNotifierState() extends State<ModelReadyNotifier> {
  late final StreamSubscription<ModelDownloadState> _sub;

  /// The last state seen; null before the first.
  ModelDownloadState? _last;

  @override
  void initState() {
    super.initState();
    _sub = GetIt.I<ModelDownload>().watch().listen((state) {
      final last = _last;
      _last = state;
      // Ready at startup is not news; coming from a download is.
      if (state is ModelDownloadReady && last != null && last is! ModelDownloadReady && last is! ModelDownloadAbsent) {
        _show();
      }
    });
  }

  void _show() {
    if (!mounted) return;
    final now = GetIt.I<Clock>().now;
    PostinoSnackbar.show(
      context,
      message: context.t.etichetteAutomatiche.model.readySnackbar,
      actionLabel: context.t.etichetteAutomatiche.model.dismiss,
      onAction: () {},
      until: now().add(const Duration(seconds: 5)),
      now: now,
    );
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
