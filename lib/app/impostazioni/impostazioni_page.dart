import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../features/impostazioni/presentation/device_settings_view.dart';
import '../../main.dart' show routePaths;

/// `/impostazioni`: the Impostazioni del dispositivo, pushed over the Posta views; back pops to them.
class ImpostazioniPage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const ImpostazioniPage({super.key});

  @override
  Widget build(BuildContext context) => DeviceSettingsView(
    // Opened by a link with nothing under it: back to the Posta unificata.
    onBack: () =>
        Navigator.of(context).canPop() ? Routefly.pop<void>(context) : Routefly.navigate(routePaths.posta.path),
  );
}
