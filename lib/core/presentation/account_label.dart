import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../domain/account.dart';

/// How [account] reads wherever Accounts are listed: its name, with its Provider («ada@acme.com · Gmail») when
/// another Account of [all] has the same address (ADR 0016, #191), so the two never read the same.
String accountLabel(BuildContext context, Account account, List<Account> all) =>
    all.where((b) => b.address == account.address).length > 1
    ? '${account.name} · ${providerName(context, account.provider)}'
    : account.name;

/// The name of [provider] as the user knows it.
String providerName(BuildContext context, ProviderKind provider) => switch (provider) {
  ProviderKind.gmail => context.t.accounts.gmail,
  ProviderKind.microsoft => context.t.accounts.microsoft,
  ProviderKind.icloud => context.t.accounts.icloud,
  ProviderKind.imap => context.t.accounts.imap,
};
