import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/launch_at_login_use_case.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'escape_to_go_back.dart';

/// The Impostazioni (the drawer's last entry): those of the device, then one group per Account.
/// Routing is the caller's: Esc and the back arrow call [onBack].
class const SettingsIndexView({
  super.key,
  required final VoidCallback onBack,
  required final VoidCallback onOpenDevice,
  required final void Function(String accountId) onOpenAutoLabels,
}) extends StatefulWidget {
  @override
  State<SettingsIndexView> createState() => _SettingsIndexViewState();
}

class _SettingsIndexViewState() extends State<SettingsIndexView> with AccountsSignal {
  @override
  Widget build(BuildContext context) => EscapeToGoBack(
    onBack: widget.onBack,
    child: SignalBuilder(
      builder: (context) => PostinoSettingsPage(
        title: context.t.impostazioni.title,
        onBack: widget.onBack,
        sections: [
          // ponytail: the device has only the avvio al login so far, so it shows where that exists (desktop).
          if (GetIt.I<LaunchAtLoginUseCase>().supported)
            PostinoSettingsSection(
              title: context.t.impostazioni.deviceSection,
              children: [
                PostinoSettingsItem(
                  key: const ValueKey('settings-device'),
                  title: context.t.impostazioni.device,
                  onTap: widget.onOpenDevice,
                ),
              ],
            ),
          for (final a in accounts.value.value ?? const <Account>[])
            PostinoSettingsSection(
              title: a.name,
              children: [
                PostinoSettingsItem(
                  key: ValueKey('settings-auto-labels-${a.id}'),
                  title: context.t.etichetteAutomatiche.title,
                  onTap: () => widget.onOpenAutoLabels(a.id),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
