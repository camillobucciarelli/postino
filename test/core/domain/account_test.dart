import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';

import '../../support/value_equality.dart';

Account _account({
  String id = 'a1',
  String address = 'a@x.it',
  ProviderKind provider = ProviderKind.gmail,
  int color = 0,
  int position = 0,
  AccountStatus status = AccountStatus.attivo,
}) => Account(
  id: id,
  address: address,
  provider: provider,
  color: color,
  position: position,
  status: status,
);

void main() {
  test('Account compares by value (#94)', () {
    expectValueEquality(_account, [
      _account(id: 'a2'),
      _account(address: 'b@x.it'),
      _account(provider: ProviderKind.imap),
      _account(color: 1),
      _account(position: 1),
      _account(status: AccountStatus.daRicollegare),
    ]);
  });
}
