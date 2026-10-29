import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

import '../../main.dart' show routePaths;
import '../../features/account/presentation/onboarding_gate.dart';
import '../../features/account/presentation/reconnect_banners.dart';
import '../../features/posta/presentation/offline_indicator.dart';
import '../../features/posta/presentation/account_list.dart';
import '../../features/posta/presentation/message_list.dart';
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
    if (Routefly.currentOriginalPath != own) {
      // Account and Etichetta views also tell about a Da ricollegare Account.
      return const Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ReconnectBanners(),
              Expanded(child: RouterOutlet()),
            ],
          ),
        ),
      );
    }
    return OnboardingGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t.appTitle),
          actions: const [OfflineIndicator()],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.t.postaUnificata),
            ),
            const ReconnectBanners(),
            AccountList(
              onOpen: (id) => Routefly.push(
                routePaths.posta.$accountId.path.changes({'accountId': id}),
              ),
            ),
            Expanded(child: MessageList(watch: (r) => r.watchUnifiedInbox())),
          ],
        ),
      ),
    );
  }
}
