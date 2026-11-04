// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../../../main.dart' show routePaths;
import '../../posta_views.dart';

/// Route of a Conversazione: PostaLayout draws it, beside or over its list, from the URI.
class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context) => postaConversationView(
    Routefly.query['accountId'],
    Routefly.query['conversationId'],
    onBack: () => Routefly.navigate(
      routePaths.posta.$accountId.path.changes({
        'accountId': Routefly.query['accountId'],
      }),
    ),
    onOpenDraft: (id) => Routefly.navigate(
      routePaths.posta.$accountId.bozza.$messageId.changes({
        'accountId': Routefly.query['accountId'],
        'messageId': Uri.encodeComponent(id),
      }),
    ),
  );
}
