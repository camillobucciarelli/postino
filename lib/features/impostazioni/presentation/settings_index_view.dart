import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/app_updater.dart';
import '../../../core/domain/launch_at_login_use_case.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'escape_to_go_back.dart';
import 'sync_account_section.dart';

/// The Impostazioni (the drawer's last entry): those of the device, then one group per Account.
/// Routing is the caller's: Esc and the back arrow call [onBack].
class const SettingsIndexView({
  super.key,
  required final VoidCallback onBack,
  required final VoidCallback onOpenDevice,
  required final void Function(String accountId) onOpenAutoLabels,
  required final VoidCallback onReportProblem,
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
          // The device has the avvio al login (desktop) and the aggiornamenti (macOS): it shows where either exists.
          if (GetIt.I<LaunchAtLoginUseCase>().supported || GetIt.I<AppUpdater>().supported)
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
          const SyncAccountSection(),
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
          PostinoSettingsSection(
            title: context.t.appTitle,
            children: [
              PostinoSettingsItem(
                key: const ValueKey('settings-report-problem'),
                title: context.t.segnalazione.action,
                onTap: widget.onReportProblem,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
