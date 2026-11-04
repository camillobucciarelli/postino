import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/mail_notification.dart';
import '../../../core/domain/open_conversation.dart';

/// Tells [OpenConversation] while the Conversazione is really on screen (#39), so its new messages are not notified:
/// open, the app in front, and no full page pushed over it (Impostazioni). In the tray, in the background, behind
/// another app or under another page its new messages are notified. A pageless route over it does not hide it: a
/// dialog or a menu, and «Vedi originale», which shows a message of this same Conversazione.
mixin ConversationOnScreen<T extends StatefulWidget> on State<T> {
  /// The Conversazione this State shows.
  ConversationKey get conversationKey;

  late final _lifecycle = AppLifecycleListener(onStateChange: (_) => _update());

  /// A full page is pushed over its route.
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of rebuilds this whenever a route is pushed over its own or popped. A page (routefly's pages) above
    // covers it; a pageless route (a dialog, a menu) does not.
    final route = ModalRoute.of(context);
    final pages = Navigator.maybeOf(context)?.widget.pages ?? const <Page<Object?>>[];
    _covered = route != null && !route.isCurrent && pages.isNotEmpty && pages.last != route.settings;
    _update();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    GetIt.I<OpenConversation>().hide(conversationKey);
    super.dispose();
  }

  void _update() {
    final open = GetIt.I<OpenConversation>();
    final inFront = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed => true,
      _ => false,
    };
    inFront && !_covered ? open.show(conversationKey) : open.hide(conversationKey);
  }
}
