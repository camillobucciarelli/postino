import 'package:flutter/widgets.dart';

import '../../features/impostazioni/presentation/device_settings_view.dart';
import 'impostazioni_page.dart';

/// `/impostazioni/dispositivo`: the Impostazioni del dispositivo.
class DevicePage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) => DeviceSettingsView(onBack: () => goBackOrToPosta(context));
}
