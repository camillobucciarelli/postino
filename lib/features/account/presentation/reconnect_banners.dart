// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'connect_error.dart';
import 'oauth_connect.dart';
import 'password_account_form.dart';

/// One `warning` Banner per Da ricollegare Account, offering to sign in again: the consent of the Provider for Gmail and
/// Microsoft, the password form with the address locked for iCloud and IMAP.
class const ReconnectBanners({super.key}) extends StatefulWidget {
  @override
  State<ReconnectBanners> createState() => _ReconnectBannersState();
}

class _ReconnectBannersState() extends State<ReconnectBanners> with AccountsSignal {
  Future<void> _reconnect(Account a) async {
    final consent = connectWithConsent(GetIt.I<AccountsRepository>(), a.provider, loginHint: a.address);
    if (consent == null) {
      await showPasswordAccountForm(context, icloud: a.provider == ProviderKind.icloud, address: a.address);
      return;
    }
    final r = await consent;
    if (!mounted) return;
    if (connectError(context, r, provider: a.provider) case final e?) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
    }
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in accounts.value.value ?? const <Account>[])
          if (a.status == AccountStatus.daRicollegare)
            PostinoBanner(
              key: ValueKey('da-ricollegare-${a.id}'),
              tone: PostinoBannerTone.warning,
              icon: PostinoIcons.key,
              account: (color: PostinoAccountColor.values[a.color], initial: a.initial),
              title: context.t.daRicollegare.title(name: a.name),
              message: switch (a.provider) {
                ProviderKind.gmail => context.t.daRicollegare.message,
                ProviderKind.microsoft => context.t.daRicollegare.microsoftMessage,
                ProviderKind.icloud || ProviderKind.imap => context.t.daRicollegare.passwordMessage,
              },
              actionLabel: context.t.daRicollegare.signIn,
              onAction: () => _reconnect(a),
            ),
      ],
    ),
  );
}
