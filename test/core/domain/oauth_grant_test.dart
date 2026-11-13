import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/oauth_grant.dart';

import '../../support/value_equality.dart';

OAuthGrant _grant({
  String address = 'a@x.it',
  String accessToken = 'secret-access',
  String refreshToken = 'secret-refresh',
  DateTime? expiresAt,
}) => OAuthGrant(
  address: address,
  accessToken: accessToken,
  refreshToken: refreshToken,
  expiresAt: expiresAt ?? DateTime.utc(2026),
);

void main() {
  test('OAuthGrant compares by value (#94)', () {
    expectValueEquality(_grant, [
      _grant(address: 'b@x.it'),
      _grant(accessToken: 'other'),
      _grant(refreshToken: 'other'),
      _grant(expiresAt: DateTime.utc(2027)),
    ]);
  });

  test('OAuthGrant never prints its tokens', () {
    expect(_grant().toString(), isNot(contains('secret')));
  });
}
