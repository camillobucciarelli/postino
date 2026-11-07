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

/// The Impostazioni (the drawer's last entry): those of the device, the «Account» list with «Aggiungi Account»
/// ([onAddAccount]), then one group per Account.
/// Routing is the caller's: Esc and the back arrow call [onBack].
class const SettingsIndexView({
  super.key,
  required final VoidCallback onBack,
  required final VoidCallback onOpenDevice,
  required final void Function(String accountId) onOpenAutoLabels,
  required final VoidCallback onOpenSwipe,
  required final VoidCallback onReportProblem,
  required final VoidCallback onAddAccount,
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
          PostinoSettingsSection(
            title: context.t.accounts.section,
            children: [
              for (final a in accounts.value.value ?? const <Account>[])
                // ponytail: listed only; color, order and Rimozione arrive with user stories 8/12/96 of #28.
                PostinoSettingsItem(
                  key: ValueKey('settings-account-${a.id}'),
                  title: a.name,
                  subtitle: [
                    _providerName(context, a.provider),
                    if (a.status == AccountStatus.daRicollegare) context.t.daRicollegare.status,
                  ].join(' · '),
                  onTap: null,
                ),
              PostinoSettingsItem(
                key: const ValueKey('settings-add-account'),
                title: context.t.accounts.add,
                onTap: widget.onAddAccount,
              ),
            ],
          ),
          const SyncAccountSection(),
          for (final a in accounts.value.value ?? const <Account>[])
            PostinoSettingsSection(
              title: _sectionTitle(context, a, accounts.value.value!),
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
                key: const ValueKey('settings-swipe'),
                title: context.t.scorrimento.title,
                onTap: widget.onOpenSwipe,
              ),
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

/// The Account's name, with its Provider when another Account has the same address (ADR 0016): two sections must
/// not read the same.
String _sectionTitle(BuildContext context, Account a, List<Account> all) =>
    all.where((b) => b.address == a.address).length > 1 ? '${a.name} · ${_providerName(context, a.provider)}' : a.name;

String _providerName(BuildContext context, ProviderKind p) => switch (p) {
  ProviderKind.gmail => context.t.accounts.gmail,
  ProviderKind.microsoft => context.t.accounts.microsoft,
  ProviderKind.icloud => context.t.accounts.icloud,
  ProviderKind.imap => context.t.accounts.imap,
};
