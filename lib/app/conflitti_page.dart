import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../features/posta/presentation/conflicts_screen.dart';
import 'impostazioni/impostazioni_page.dart' show goBackOrToPosta;

/// `/conflitti[?accountId=…]`: the open Conflitti, pushed over the Posta views; back pops to them.
class ConflictsPage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const ConflictsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      ConflictsScreen(accountId: Routefly.query.params['accountId'], onBack: () => goBackOrToPosta(context));
}
