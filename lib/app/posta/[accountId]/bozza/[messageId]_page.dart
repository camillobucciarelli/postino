// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../../../main.dart' show routePaths;
import '../../posta_views.dart';
import '../../route_query.dart';

/// Route of a Bozza being written: PostaLayout draws the composer, beside or over its list, from the URI
/// (the Message-ID is percent-encoded in the path).
class DraftPage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const DraftPage({super.key});

  @override
  Widget build(BuildContext context) => postaComposerView(
    Routefly.query.param('accountId'),
    Routefly.query.param('messageId'),
    onClose: () =>
        Routefly.navigate(routePaths.posta.$accountId.path.changes({'accountId': Routefly.query.param('accountId')})),
    // Never drawn: PostaLayout draws the composer itself, with Annulla invio; here the composer just closes.
    onQueued: (accountId, _, _) =>
        Routefly.navigate(routePaths.posta.$accountId.path.changes({'accountId': accountId})),
  );
}
