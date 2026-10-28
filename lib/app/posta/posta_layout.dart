import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

import '../../features/account/presentation/onboarding_gate.dart';
import '../../features/account/presentation/reconnect_banners.dart';
import '../../features/posta/presentation/unified_inbox.dart';
import '../../i18n/strings.g.dart';

/// Layout of `/posta`: child routes render in the [RouterOutlet]; with no child
/// active (URL exactly `/posta`) it shows the Posta unificata itself, since in
/// routefly a page at the layout's own path cannot be its child.
class PostaLayout extends StatelessWidget {
  const PostaLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Routefly.of subscribes to route changes; the last configuration is the active route.
    final own = Routefly.of(context).route.uri.path;
    if (Routefly.currentOriginalPath != own) return const RouterOutlet();
    return OnboardingGate(
      child: Scaffold(
        appBar: AppBar(title: Text(context.t.appTitle)),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.t.postaUnificata),
            ),
            const ReconnectBanners(),
            const Expanded(child: UnifiedInbox()),
          ],
        ),
      ),
    );
  }
}
