import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/error_log/log_redaction.dart';

void main() {
  test('Bearer tokens are redacted, in a header and on their own', () {
    final header = redactSecrets('GET /gmail/v1 failed, Authorization: Bearer ya29.a0AfB_xyz-123');
    expect(header, isNot(contains('a0AfB_xyz')));
    expect(header, contains('Authorization: [redatto]'));
    expect(
      redactSecrets('sasl user=a@example.com auth=Bearer abc123 end'),
      'sasl user=a@example.com auth=Bearer [redatto] end',
    );
  });

  // Every secret below contains SECRET; none of it may survive, and the quotes around a field stay balanced.
  const table = {
    r'{"password":"prefix Bearer abc\"SECRET"}': '{"password":"[redatto]"}',
    r"{'password': 'pre fix\'SECRET'}": "{'password': '[redatto]'}",
    r'{"token": "a b\\\"SECRET c"}': '{"token": "[redatto]"}',
    '{"Authorization": "Bearer SECRET"}': '{"Authorization": "[redatto]"}',
    r'{"body":"{\"refresh_token\":\"SEC,RET\"}"}': r'{"body":"{\"refresh_token\":\"[redatto]\""}',
    'password=SECRET&x=1': 'password=[redatto]&x=1',
    "client_secret='SEC RET' next": "client_secret='[redatto]' next",
    '{password: first SECRET, user: u}': '{password: [redatto], user: u}',
    'Authorization: Bearer SECRET': 'Authorization: [redatto]',
    r'a1 LOGIN "u" "pa\"SECRET"': 'a1 LOGIN [redatto]',
    'msg "Bearer SECRET" end': 'msg "Bearer [redatto]" end',
    "msg 'x Bearer SECRET' end": "msg 'x Bearer [redatto]' end",
    // JSON inside a JSON string, the password with a quote: the rest of the outer string goes, its quote stays.
    r'{"body":"{\"password\":\"prefix\\\"SECRET\"}"}': r'{"body":"{\"password\":\"[redatto]\""}',
    r'password=\SECRET': 'password=[redatto]',
    // Cut short (a FormatException shows ~78 characters of its source).
    '{"password":"prefixSECRET': '{"password":"[redatto]',
    'password="hunter2SECRET': 'password="[redatto]',
    // Unquoted inside a quoted string or parentheses: the closer stays, a quote or comma inside the value does not.
    'msg "password=SECRET" end': 'msg "password=[redatto]" end',
    '{"err":"password=SECRET","user":"u@x.it"}': '{"err":"password=[redatto]","user":"u@x.it"}',
    'Exception(password=SECRET) at foo': 'Exception(password=[redatto]) at foo',
    'password=ab"SECRET': 'password=[redatto]',
    'password=a,SECRET': 'password=[redatto]',
    'msg "a1 LOGIN u SECRET" end': 'msg "a1 LOGIN [redatto]" end',
    'a1 LOGIN {4}\r\nuser {6}\r\nSECRET': 'a1 LOGIN [redatto]',
  };
  for (final MapEntry(key: input, value: expected) in table.entries) {
    test('no fragment survives: $input', () {
      final out = redactSecrets(input);
      expect(out, isNot(contains('SECRET')));
      expect(out, isNot(contains('RET')));
      expect(out, expected);
    });
  }

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

  test('an escaped quote or a space never lets part of a password through', () {
    final out = redactSecrets(
      r'a1 LOGIN "u" "pa\"ss-secret" {"password":"prefix\"SECRET_a"} {password: first SECRET_b, user: u}',
    );
    for (final secret in ['ss-secret', 'SECRET_a', 'SECRET_b']) {
      expect(out, isNot(contains(secret)), reason: secret);
    }
    expect(out, contains('user: u'));
  });

  test('ordinary words keep the address and the status: only the IMAP command and the OAuth parameter go', () {
    const text = 'Login to mario@example.com failed, HttpException: status code: 401';
    expect(redactSecrets(text), text);
  });
}
