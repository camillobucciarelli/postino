import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'connect_error.dart';

/// One `warning` Banner per Da ricollegare Account, offering to sign in again.
class ReconnectBanners extends StatefulWidget {
  const ReconnectBanners({super.key});

  @override
  State<ReconnectBanners> createState() => _ReconnectBannersState();
}

class _ReconnectBannersState extends State<ReconnectBanners> with AccountsSignal {
  Future<void> _reconnect(Account a) async {
    final r = await GetIt.I<AccountsRepository>().connectGmail(loginHint: a.address);
    if (!mounted) return;
    if (connectError(context, r) case final e?) {
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
              // ponytail: the message names Google, the one Provider of v1 step 1.
              message: context.t.daRicollegare.message,
              actionLabel: context.t.daRicollegare.signIn,
              onAction: () => _reconnect(a),
            ),
      ],
    ),
  );
}
