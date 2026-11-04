import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/error_log/log_redaction.dart';

void main() {
  test('Bearer tokens are redacted', () {
    final out = redactSecrets('GET /gmail/v1 failed, Authorization: Bearer ya29.a0AfB_xyz-123');
    expect(out, isNot(contains('a0AfB_xyz')));
    expect(out, contains('Bearer [redatto]'));
  });

  test('token and password fields are redacted, in JSON, forms and query strings', () {
    final out = redactSecrets(
      '{"access_token": "abc.def", "refresh_token":"1//0gXyz", "expires_in": 3599} '
      'grant_type=refresh_token&refresh_token=r3fr3sh&client_secret=s3cr3t '
      'https://x.test/cb?code=4/0Ab&state=ok password=hunter2 passwd: "p@ss word"',
    );
    for (final secret in ['abc.def', '1//0gXyz', 'r3fr3sh', 's3cr3t', '4/0Ab', 'hunter2', 'p@ss word']) {
      expect(out, isNot(contains(secret)), reason: secret);
    }
    expect(out, contains('"expires_in": 3599'));
    expect(out, contains('state=ok'));
    expect(out, contains('grant_type=refresh_token'));
  });

  test('bare Google tokens are redacted wherever they appear', () {
    final out = redactSecrets('token ya29.A0ARrdaM-abc_DEF and 1//03xYz-AbC_dEf in the text');
    expect(out, isNot(contains('A0ARrdaM')));
    expect(out, isNot(contains('03xYz')));
  });

  test('IMAP LOGIN and AUTHENTICATE lines lose their credentials', () {
    final out = redactSecrets(
      'a1 LOGIN "user@example.com" "app-password-123"\na2 AUTHENTICATE XOAUTH2 dXNlcj1hQGIuYwFhdXRo',
    );
    expect(out, isNot(contains('app-password-123')));
    expect(out, isNot(contains('dXNlcj1hQGIuYwFhdXRo')));
    expect(out, contains('LOGIN [redatto]'));
    expect(out, contains('AUTHENTICATE XOAUTH2 [redatto]'));
  });

  test('subjects and addresses stay', () {
    const text = '[sync] gmail:mario.rossi@example.com: failed, Oggetto «Fattura di ottobre» da anna@example.org';
    expect(redactSecrets(text), text);
  });
}
