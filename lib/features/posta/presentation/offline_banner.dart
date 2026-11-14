import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// The `offline` Banner on top of the list while the device is offline; nothing otherwise. It opens and closes
/// (PostinoReveal, #283).
class const OfflineBanner({super.key}) extends StatefulWidget {
  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState() extends State<OfflineBanner> {
  final _connectivity = GetIt.I<Connectivity>();
  late final online = streamSignal(
    () => _connectivity.onChanged,
    options: AsyncSignalOptions(initialValue: _connectivity.isOnline),
  );

  @override
  void dispose() {
    online.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => PostinoReveal(
      child: (online.value.value ?? true)
          ? null
          : PostinoBanner(
              key: const ValueKey('offline-banner'),
              tone: PostinoBannerTone.offline,
              title: context.t.offline.title,
              message: context.t.offline.message,
            ),
    ),
  );
}
