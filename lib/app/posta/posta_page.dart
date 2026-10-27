import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';

// ponytail: placeholder for Posta unificata; no posta_layout.dart yet because routefly 3.1.3
// maps posta_layout.dart and posta_page.dart in the same folder to the same key '/posta'.
class UnifiedInboxPage extends StatelessWidget {
  const UnifiedInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.appTitle)),
      body: Center(child: Text(context.t.inbox)),
    );
  }
}
