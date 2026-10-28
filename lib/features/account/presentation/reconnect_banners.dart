import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../i18n/strings.g.dart';

/// One banner per Da ricollegare Account, offering to consent again.
class ReconnectBanners extends StatefulWidget {
  const ReconnectBanners({super.key});

  @override
  State<ReconnectBanners> createState() => _ReconnectBannersState();
}

class _ReconnectBannersState extends State<ReconnectBanners> {
  late final accounts = streamSignal(
    () => GetIt.I<AccountsRepository>().watchAccounts(),
  );

  @override
  void dispose() {
    accounts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => Column(
      children: [
        for (final a in accounts.value.value ?? const <Account>[])
          if (a.status == AccountStatus.daRicollegare)
            MaterialBanner(
              key: ValueKey('da-ricollegare-${a.id}'),
              leading: Icon(Icons.circle, color: Color(a.color), size: 12),
              content: Text(context.t.daRicollegare.banner(address: a.address)),
              actions: [
                TextButton(
                  // ponytail: Gmail only, the one Provider of v1 step 1.
                  onPressed: () => GetIt.I<AccountsRepository>().connectGmail(
                    loginHint: a.address,
                  ),
                  child: Text(context.t.daRicollegare.reconnect),
                ),
              ],
            ),
      ],
    ),
  );
}
