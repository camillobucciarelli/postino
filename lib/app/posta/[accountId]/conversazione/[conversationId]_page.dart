// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../../../main.dart' show routePaths;
import '../../posta_views.dart';
import '../../route_query.dart';

/// Route of a Conversazione: PostaLayout draws it, beside or over its list, from the URI.
class const ConversationPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => postaConversationView(
    Routefly.query.param('accountId'),
    Routefly.query.param('conversationId'),
    onBack: () =>
        Routefly.navigate(routePaths.posta.$accountId.path.changes({'accountId': Routefly.query.param('accountId')})),
    onOpenDraft: (id) => Routefly.navigate(
      routePaths.posta.$accountId.bozza.$messageId.changes({
        'accountId': Routefly.query.param('accountId'),
        'messageId': Uri.encodeComponent(id),
      }),
    ),
  );
}
