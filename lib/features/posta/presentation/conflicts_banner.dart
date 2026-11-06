import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// The «N conflitti» Banner on top of an inbox: all the Accounts' in the Posta unificata, only [accountId]'s in an
/// Account's; nothing at 0. It is a live region, so a screen reader announces it when N changes; «Vedi» ([onOpen])
/// opens the list of the Conflitti it counts.
class const ConflictsBanner({super.key, required final VoidCallback onOpen, final String? accountId})
    extends StatefulWidget {
  @override
  State<ConflictsBanner> createState() => _ConflictsBannerState();
}

class _ConflictsBannerState() extends State<ConflictsBanner> {
  late final count = streamSignal(
    () => GetIt.I<InboxRepository>().watchConflicts(accountId: widget.accountId).map((l) => l.length),
  );

  @override
  void dispose() {
    count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final n = count.value.value ?? 0;
      if (n == 0) return const SizedBox.shrink();
      final t = context.t.conflitti;
      return PostinoBanner(
        key: const ValueKey('conflicts-banner'),
        tone: PostinoBannerTone.warning,
        title: t.bannerTitle(n: n),
        message: t.bannerMessage,
        actionLabel: t.open,
        onAction: widget.onOpen,
      );
    },
  );
}
