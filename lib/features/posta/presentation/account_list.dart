import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';

/// One chip per Account, opening its inbox; routing is the caller's ([onOpen]), features don't know the routes.
class AccountList extends StatefulWidget {
  const AccountList({super.key, required this.onOpen});
  final void Function(String accountId) onOpen;

  @override
  State<AccountList> createState() => _AccountListState();
}

class _AccountListState extends State<AccountList> {
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
    builder: (context) => Wrap(
      spacing: 8,
      children: [
        for (final a in accounts.value.value ?? const <Account>[])
          ActionChip(
            key: ValueKey('account-${a.id}'),
            avatar: Icon(Icons.circle, color: Color(a.color), size: 12),
            label: Text(a.address),
            onPressed: () => widget.onOpen(a.id),
          ),
      ],
    ),
  );
}
