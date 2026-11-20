import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';

import '../../../support/fake_platform.dart';

void main() {
  test('a token saved before the extraction (Gmail, #179) is still read, under the same key', () async {
    final keychain = FakeSecureStore();
    await keychain.write(
      'oauth:gmail:ada@gmail.com',
      '{"access":"ya29.old","refresh":"1//old","expiresAt":"2026-10-28T13:00:00.000Z"}',
    );

    final tokens = await OAuthTokens.read(keychain, 'gmail:ada@gmail.com');

    expect((tokens!.access, tokens.refresh), ('ya29.old', '1//old'));
    expect(tokens.expiresAt, DateTime.utc(2026, 10, 28, 13));
  });

  test('whether the refresh token came from the synced file is kept; a token saved before says no (#353)', () async {
    final keychain = FakeSecureStore();
    for (final synced in [true, false]) {
      await OAuthTokens(access: 'a', refresh: 'r', expiresAt: DateTime.utc(2030), synced: synced).write(keychain, 'x');
      expect((await OAuthTokens.read(keychain, 'x'))!.synced, synced);
    }
    expect(keychain.values['oauth:x'], isNot(contains('synced')), reason: 'written only when true');
  });

  test('every Provider keeps its tokens under oauth:<accountId>', () async {
    final keychain = FakeSecureStore();
    await OAuthTokens(
      access: 'a',
      refresh: 'r',
      expiresAt: DateTime.utc(2030),
    ).write(keychain, 'microsoft:ada@outlook.com');

    expect(keychain.values.keys, ['oauth:microsoft:ada@outlook.com']);
    await OAuthTokens.delete(keychain, 'microsoft:ada@outlook.com');
    expect(keychain.values, isEmpty);
  });
}
