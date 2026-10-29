// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../../../design_system/design_system.dart';
import '../../../../features/posta/presentation/message_list.dart';
import '../../../../features/posta/presentation/posta_app_bars.dart';
import '../../posta_layout.dart';

/// The messages of one Etichetta of an Account.
class LabelPage extends StatelessWidget {
  const LabelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String accountId = Routefly.query['accountId'];
    final String labelId = Routefly.query['labelId'];
    return PostinoAdaptiveLayout(
      key: ValueKey('$accountId/$labelId'),
      appBar: AccountAppBar(accountId: accountId, labelId: labelId),
      drawer: postaDrawer(accountId: accountId, labelId: labelId),
      banners: postaBanners,
      body: MessageList(watch: (r) => r.watchMessages(accountId, labelId)),
    );
  }
}
