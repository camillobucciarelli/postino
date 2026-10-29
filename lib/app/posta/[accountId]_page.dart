// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../core/domain/message.dart' show inboxLabelId;
import '../../design_system/design_system.dart';
import '../../features/posta/presentation/message_list.dart';
import '../../features/posta/presentation/posta_app_bars.dart';
import 'posta_layout.dart';

/// An Account's inbox.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String id = Routefly.query['accountId'];
    return PostinoSinglePaneLayout(
      // A new Account is a new view: its streams start over.
      key: ValueKey(id),
      appBar: AccountAppBar(accountId: id),
      drawer: postaDrawer(accountId: id),
      banners: postaBanners,
      body: MessageList(watch: (r) => r.watchMessages(id, inboxLabelId)),
    );
  }
}
