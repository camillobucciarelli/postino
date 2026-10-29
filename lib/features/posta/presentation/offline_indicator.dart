import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/platform_services.dart';
import '../../../i18n/strings.g.dart';

/// Discreet mark while the device is offline; nothing otherwise.
class OfflineIndicator extends StatefulWidget {
  const OfflineIndicator({super.key});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
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
    builder: (context) {
      if (online.value.value ?? true) return const SizedBox.shrink();
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;
      return Tooltip(
        key: const ValueKey('offline-indicator'),
        message: context.t.offline.tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 16, color: muted),
              const SizedBox(width: 4),
              Text(
                context.t.offline.label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      );
    },
  );
}
