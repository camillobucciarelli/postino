import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// «Rimuovi» on an Account (#174): asks first, the focus on «Annulla» (Esc answers no too), then removes it.
/// True when it was removed.
Future<bool> confirmRemoveAccount(BuildContext context, Account account) async {
  final t = context.t.accounts;
  final confirmed = await showPostinoConfirmDialog(
    context,
    title: t.removeTitle(name: account.name),
    message: t.removeMessage,
    note: t.removeNote,
    confirmLabel: t.removeConfirm,
    cancelLabel: t.removeCancel,
  );
  if (!confirmed) return false;
  await GetIt.I<AccountsRepository>().remove(account.id);
  return true;
}
