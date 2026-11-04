import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/google_consent.dart';

import '../../support/value_equality.dart';

GoogleGrant _grant({
  String address = 'a@x.it',
  String accessToken = 'secret-access',
  String refreshToken = 'secret-refresh',
  DateTime? expiresAt,
}) => GoogleGrant(
  address: address,
  accessToken: accessToken,
  refreshToken: refreshToken,
  expiresAt: expiresAt ?? DateTime.utc(2026),
);

void main() {
  test('GoogleGrant compares by value (#94)', () {
    expectValueEquality(() => _grant(), [
      _grant(address: 'b@x.it'),
      _grant(accessToken: 'other'),
      _grant(refreshToken: 'other'),
      _grant(expiresAt: DateTime.utc(2027)),
    ]);
  });

  test('GoogleGrant never prints its tokens', () {
    expect(_grant().toString(), isNot(contains('secret')));
  });
}
