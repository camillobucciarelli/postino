import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/settings_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// «Rimuovi» on an Account (#174): asks first, the focus on «Annulla» (Esc answers no too), then removes it. With the
/// sync on the dialog says the Account and its access go from every paired device (ADR 0019); for Gmail, that
/// Postino stays authorized in the Google account, as nothing is revoked there (#353).
/// True when the removal left no Account (read once it is done: another removal may have run meanwhile).
Future<bool> confirmRemoveAccount(BuildContext context, Account account) async {
  final t = context.t.accounts;
  final syncAccount = await GetIt.I<SettingsRepository>().settingsSyncAccount();
  if (!context.mounted) return false;
  final confirmed = await showPostinoConfirmDialog(
    context,
    title: t.removeTitle(name: account.name),
    message: t.removeMessage,
    note: [
      t.removeNote,
      if (syncAccount != null) t.removeSyncedNote,
      if (account.provider == ProviderKind.gmail) t.removeGmailNote,
    ].join('\n'),
    confirmLabel: t.removeConfirm,
    cancelLabel: t.removeCancel,
  );
  if (!confirmed) return false;
  final accounts = GetIt.I<AccountsRepository>();
  try {
    await accounts.remove(account.id);
  } on Object catch (e) {
    // ponytail: the Account stays listed, which shows the removal did not happen; a message if people miss it.
    debugPrint('[accounts] removal failed, ${e.runtimeType}');
    return false;
  }
  return (await accounts.watchAccounts().first).isEmpty;
}
