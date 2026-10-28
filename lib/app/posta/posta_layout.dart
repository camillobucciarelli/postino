import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

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
    // ponytail: placeholder for Posta unificata, replaced by the posta feature's presentation.
    return Scaffold(
      appBar: AppBar(title: Text(context.t.appTitle)),
      body: Center(child: Text(context.t.inbox)),
    );
  }
}
