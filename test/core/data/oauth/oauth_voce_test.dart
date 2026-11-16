// The value of an OAuth voce and its scope rule (ADR 0019, #321).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/oauth/oauth_voce.dart';

OAuthVoce _with(List<String> scopes) => OAuthVoce(refresh: 'r', scopes: scopes);

void main() {
  test('fewer API scopes is narrower; the scopes that only name the user do not count', () {
    const drive = 'https://www.googleapis.com/auth/drive.appdata';
    const mail = 'https://mail.google.com/';
    expect(_with([mail, 'openid', 'email']).narrowerThan([mail, drive]), isTrue);
    expect(_with([mail, drive]).narrowerThan([mail, 'openid']), isFalse);
    // A refresh does not repeat openid nor userinfo.email: the same token, not a narrower one.
    expect(_with([mail]).narrowerThan([mail, 'openid', 'https://www.googleapis.com/auth/userinfo.email']), isFalse);
    expect(_with([mail, 'profile', 'offline_access']).narrowerThan([mail]), isFalse);
  });

  test('Graph scopes count the same with or without their prefix, in any case', () {
    expect(
      _with(['Mail.ReadWrite', 'Mail.Send'])
          .narrowerThan(['https://graph.microsoft.com/Mail.ReadWrite', 'https://graph.microsoft.com/mail.send']),
      isFalse,
    );
    expect(_with(['Mail.ReadWrite']).narrowerThan(['https://graph.microsoft.com/Mail.ReadWrite', 'Mail.Send']), isTrue);
  });

  test('the same token always encodes the same, and never prints itself', () {
    expect(_with(['b', 'a']).encode(), _with(['a', 'b']).encode());
    expect(OAuthVoce.decode(_with(['a']).encode()).scopes, ['a']);
    expect('${const OAuthVoce(refresh: 'r-printed', scopes: [])}', isNot(contains('r-printed')));
  });
}
