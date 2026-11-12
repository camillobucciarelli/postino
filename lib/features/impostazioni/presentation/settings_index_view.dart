import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'escape_to_go_back.dart';
import 'remove_account.dart';
import 'sync_account_section.dart';

/// The Impostazioni (the drawer's last entry): those of the device, the «Account» list with «Aggiungi Account»
/// ([onAddAccount]) and «Rimuovi» on each, then one group per Account.
/// Routing is the caller's: Esc and the back arrow call [onBack], and so does removing the last Account (the
/// onboarding is under the Impostazioni).
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
  Future<void> _remove(Account account) async {
    if (await confirmRemoveAccount(context, account) && mounted) widget.onBack();
  }

  @override
  Widget build(BuildContext context) => EscapeToGoBack(
    onBack: widget.onBack,
    child: SignalBuilder(
      builder: (context) => PostinoSettingsPage(
        title: context.t.impostazioni.title,
        onBack: widget.onBack,
        sections: [
          // On every platform: the notifications are there everywhere (#211).
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
                // ponytail: color and order arrive with user stories 8/12 of #28.
                PostinoSettingsItem(
                  key: ValueKey('settings-account-${a.id}'),
                  title: a.name,
                  subtitle: [
                    _providerName(context, a.provider),
                    if (a.status == AccountStatus.daRicollegare) context.t.daRicollegare.status,
                  ].join(' · '),
                  onTap: null,
                  trailing: PostinoIconButton(
                    key: ValueKey('settings-remove-account-${a.id}'),
                    icon: PostinoIcons.trash,
                    label: context.t.accounts.remove(address: a.address),
                    onPressed: () => unawaited(_remove(a)),
                  ),
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

String _providerName(BuildContext context, ProviderKind p) => switch (p) {
  ProviderKind.gmail => context.t.accounts.gmail,
  ProviderKind.microsoft => context.t.accounts.microsoft,
  ProviderKind.icloud => context.t.accounts.icloud,
  ProviderKind.imap => context.t.accounts.imap,
};
