import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../design_system/design_system.dart';
import '../../i18n/strings.g.dart';
import '../domain/app_updater.dart';

/// A newer version of Postino (#287), on Android and iOS: «Aggiorna» opens its download (the browser, the App Store),
/// «Chiudi» hides it until a newer one. On top of the Posta lists and under «Cerca aggiornamenti» in the
/// Impostazioni, inside [padding]. Nothing while there is none.
class const AppUpdateBanner({super.key, final EdgeInsets padding = EdgeInsets.zero}) extends StatefulWidget {
  @override
  State<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState() extends State<AppUpdateBanner> {
  final _updater = GetIt.I<AppUpdater>();

  /// One subscription for the life of the widget, as ModelDownloadBanner's.
  late final _changes = _updater.changes;

  @override
  Widget build(BuildContext context) {
    final t = context.t.aggiornamenti;
    return StreamBuilder<AppUpdate?>(
      stream: _changes,
      initialData: _updater.available,
      builder: (context, snapshot) => switch (snapshot.data) {
        null => const SizedBox.shrink(),
        final update => Padding(
          padding: widget.padding,
          child: PostinoBanner(
            key: const ValueKey('update-banner'),
            tone: PostinoBannerTone.info,
            icon: PostinoIcons.download,
            title: t.available(version: update.version),
            actionLabel: t.update,
            onAction: () => unawaited(_updater.download()),
            secondaryActionLabel: t.dismiss,
            onSecondaryAction: () => unawaited(_updater.dismiss()),
          ),
        ),
      },
    );
  }
}
