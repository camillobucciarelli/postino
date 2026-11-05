import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../features/impostazioni/presentation/settings_index_view.dart';
import '../../main.dart' show routePaths;
import '../report_problem.dart';

/// `/impostazioni`: the Impostazioni, pushed over the Posta views; back pops to them.
class ImpostazioniPage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const ImpostazioniPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsIndexView(
    // Opened by a link with nothing under it: back to the Posta unificata.
    onBack: () => goBackOrToPosta(context),
    onOpenDevice: () => unawaited(Routefly.push<void>(routePaths.impostazioni.dispositivo)),
    onReportProblem: reportProblem,
    onOpenAutoLabels: (accountId) =>
        unawaited(Routefly.push<void>(routePaths.impostazioni.$accountId.etichette.changes({'accountId': accountId}))),
  );
}

/// Back to the page the Impostazioni were pushed over, or to the Posta unificata when nothing is under them.
void goBackOrToPosta(BuildContext context) =>
    Navigator.of(context).canPop() ? Routefly.pop<void>(context) : Routefly.navigate(routePaths.posta.path);
