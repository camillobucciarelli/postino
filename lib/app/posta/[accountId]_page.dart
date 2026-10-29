// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

import '../../main.dart' show routePaths;
import '../../features/posta/presentation/account_view.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => AccountView(
    accountId: Routefly.query['accountId'],
    onOpenLabel: (id) => Routefly.push(
      routePaths.posta.$accountId.etichetta.$labelId.changes({
        'accountId': Routefly.query['accountId'],
        'labelId': id,
      }),
    ),
  );
}
