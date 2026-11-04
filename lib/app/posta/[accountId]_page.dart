// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import 'posta_views.dart';
import 'route_query.dart';

/// Route of an Account's inbox: PostaLayout draws the view from the URI.
class AccountPage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => postaAccountView(Routefly.query.param('accountId'));
}
