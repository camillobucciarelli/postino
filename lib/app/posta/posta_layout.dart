import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../core/domain/message.dart' show inboxLabelId;
import '../../main.dart' show routePaths;
import '../../design_system/design_system.dart';
import '../../features/account/presentation/onboarding_gate.dart';
import '../../features/account/presentation/reconnect_banners.dart';
import '../../features/posta/presentation/message_list.dart';
import '../../features/posta/presentation/offline_banner.dart';
import '../../features/posta/presentation/posta_app_bars.dart';
import '../../features/posta/presentation/posta_drawer.dart';

/// Layout of `/posta`: draws the view of the current URI itself (unified, Account, Etichetta),
/// so the outgoing view can fade out with its own params. The child route pages just delegate here.
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
    // One shell above the content: only the content is replaced on navigation.
    // Built from the URI, not from Routefly.query, so the outgoing view keeps its own params while it fades out.
    return OnboardingGate(
      child: PostinoSidebarShell(
        drawer: postaDrawer(accountId: accountId, labelId: labelId),
        child: PostinoFadeThrough(
          transitionKey: uri.toString(),
          child: switch ((accountId, labelId)) {
            (final a?, final l?) => postaLabelView(a, l),
            (final a?, null) => postaAccountView(a),
            _ => postaUnifiedView(),
          },
        ),
      ),
    );
  }
}

/// The Posta unificata.
Widget postaUnifiedView() => PostinoAdaptiveLayout(
  appBar: const UnifiedAppBar(),
  drawer: postaDrawer(),
  banners: postaBanners,
  body: MessageList(watch: (r) => r.watchUnifiedInbox(), showAccount: true),
);

/// An Account's inbox.
Widget postaAccountView(String id) => PostinoAdaptiveLayout(
  // A new Account is a new view: its streams start over.
  key: ValueKey(id),
  appBar: AccountAppBar(accountId: id),
  drawer: postaDrawer(accountId: id),
  banners: postaBanners,
  body: MessageList(watch: (r) => r.watchMessages(id, inboxLabelId)),
);

/// The messages of one Etichetta of an Account.
Widget postaLabelView(String accountId, String labelId) =>
    PostinoAdaptiveLayout(
      key: ValueKey('$accountId/$labelId'),
      appBar: AccountAppBar(accountId: accountId, labelId: labelId),
      drawer: postaDrawer(accountId: accountId, labelId: labelId),
      banners: postaBanners,
      body: MessageList(watch: (r) => r.watchMessages(accountId, labelId)),
    );

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

void _openFromPosta(String path) => Routefly.navigate(path);
