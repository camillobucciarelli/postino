// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

import '../../../../features/posta/presentation/account_view.dart';

class LabelPage extends StatelessWidget {
  const LabelPage({super.key});

  @override
  Widget build(BuildContext context) => LabelView(
    accountId: Routefly.query['accountId'],
    labelId: Routefly.query['labelId'],
  );
}
