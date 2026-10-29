import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../main.dart' show routePaths;
import '../../design_system/design_system.dart';
import '../../features/account/presentation/onboarding_gate.dart';
import '../../features/account/presentation/reconnect_banners.dart';
import '../../features/posta/presentation/message_list.dart';
import '../../features/posta/presentation/offline_banner.dart';
import '../../features/posta/presentation/posta_app_bars.dart';
import '../../features/posta/presentation/posta_drawer.dart';

/// Layout of `/posta`: child routes render in the [RouterOutlet]; with no child
/// active (URL exactly `/posta`) it shows the Posta unificata itself, since in
/// routefly a page at the layout's own path cannot be its child.
class PostaLayout extends StatelessWidget {
  const PostaLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Routefly.of subscribes to route changes; the last configuration is the active route.
    final own = Routefly.of(context).route.uri.path;
    final unified = Routefly.currentOriginalPath == own;
    final uri = Routefly.currentUri;
    // /posta/<account>[/etichetta/<label>]: the docked drawer reads its selection from the URL.
    final seg = uri.pathSegments;
    final accountId = !unified && seg.length > 1 ? seg[1] : null;
    final labelId = !unified && seg.length > 3 ? seg[3] : null;
    // One shell above the outlet: only its content is replaced on navigation.
    return OnboardingGate(
      child: PostinoSidebarShell(
        drawer: postaDrawer(accountId: accountId, labelId: labelId),
        child: unified
            ? PostinoAdaptiveLayout(
                appBar: const UnifiedAppBar(),
                drawer: postaDrawer(),
                banners: postaBanners,
                body: MessageList(
                  watch: (r) => r.watchUnifiedInbox(),
                  showAccount: true,
                ),
              )
            : const RouterOutlet(),
      ),
    );
  }
}

/// On top of every list: offline, then the Accounts Da ricollegare.
const postaBanners = <Widget>[OfflineBanner(), ReconnectBanners()];

/// The drawer of the Posta views, with the open Account ([accountId]) and Etichetta ([labelId]).
Widget postaDrawer({String? accountId, String? labelId}) => PostaDrawer(
  accountId: accountId,
  labelId: labelId,
  onOpenUnified: () => Routefly.navigate(routePaths.posta.path),
  onOpenAccount: (id) => _openFromPosta(
    routePaths.posta.$accountId.path.changes({'accountId': id}),
  ),
  onOpenLabel: (id) => _openFromPosta(
    routePaths.posta.$accountId.etichetta.$labelId.changes({
      'accountId': accountId!,
      'labelId': id,
    }),
  ),
);

void _openFromPosta(String path) {
  // ponytail: routefly 3.1.3 navigate() reuses the entry of the same route template with its old params; going through /posta drops it.
  Routefly.navigate(routePaths.posta.path);
  Routefly.navigate(path);
}
