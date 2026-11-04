import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../domain/account.dart';
import '../domain/accounts_repository.dart';

/// The Accounts by position as a signal, shared by every widget that follows them: loading until the
/// first value, disposed with the [State].
mixin AccountsSignal<T extends StatefulWidget> on State<T> {
  late final StreamSignal<List<Account>> accounts = streamSignal(() => GetIt.I<AccountsRepository>().watchAccounts());

  @override
  @mustCallSuper
  void dispose() {
    accounts.dispose();
    super.dispose();
  }
}
