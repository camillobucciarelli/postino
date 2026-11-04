import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/error_log/log_redaction.dart';

import '../../../support/fake_secrets.dart';

/// Redacts the filled [template].
String _redact(String template) => redactSecrets(fillSecrets(template));

void main() {
  test('Bearer tokens are redacted, in a header and on their own', () {
    final header = _redact('GET /gmail/v1 failed, <AUTH>: <B> <G>a0<S>');
    expect(header, isNot(contains(fakeMarker)));
    expect(header, fillSecrets('GET /gmail/v1 failed, <AUTH>: [redatto]'));
    expect(
      _redact('sasl user=a@example.com auth=<B> <S> end'),
      fillSecrets('sasl user=a@example.com auth=<B> [redatto] end'),
    );
  });

  // Every fake secret contains fakeMarker; none of it may survive, and the quotes around a field stay balanced.
  const table = {
    r'{"<PW>":"prefix <B> abc\"<S>"}': '{"<PW>":"[redatto]"}',
    r"{'<PW>': 'pre fix\'<S>'}": "{'<PW>': '[redatto]'}",
    r'{"<TOK>": "a b\\\"<S> c"}': '{"<TOK>": "[redatto]"}',
    '{"<AUTH>": "<B> <S>"}': '{"<AUTH>": "[redatto]"}',
    r'{"body":"{\"<RT>\":\"<S>,<S2>\"}"}': r'{"body":"{\"<RT>\":\"[redatto]\""}',
    '<PW>=<S>&x=1': '<PW>=[redatto]&x=1',
    "<CS>='<S> <S2>' next": "<CS>='[redatto]' next",
    '{<PW>: first <S>, user: u}': '{<PW>: [redatto], user: u}',
    '<AUTH>: <B> <S>': '<AUTH>: [redatto]',
    r'a1 LOGIN "u" "pa\"<S>"': 'a1 LOGIN [redatto]',
    'msg "<B> <S>" end': 'msg "<B> [redatto]" end',
    "msg 'x <B> <S>' end": "msg 'x <B> [redatto]' end",
    // JSON inside a JSON string, the value with a quote: the rest of the outer string goes, its quote stays.
    r'{"body":"{\"<PW>\":\"prefix\\\"<S>\"}"}': r'{"body":"{\"<PW>\":\"[redatto]\""}',
    r'<PW>=\<S>': '<PW>=[redatto]',
    // Cut short (a FormatException shows ~78 characters of its source).
    '{"<PW>":"prefix<S>': '{"<PW>":"[redatto]',
    '<PW>="prefix<S>': '<PW>="[redatto]',
    // Unquoted inside a quoted string or parentheses: the closer stays, a quote or comma inside the value does not.
    'msg "<PW>=<S>" end': 'msg "<PW>=[redatto]" end',
    '{"err":"<PW>=<S>","user":"u@x.it"}': '{"err":"<PW>=[redatto]","user":"u@x.it"}',
    'Exception(<PW>=<S>) at foo': 'Exception(<PW>=[redatto]) at foo',
    '<PW>=ab"<S>': '<PW>=[redatto]',
    '<PW>=a,<S>': '<PW>=[redatto]',
    'msg "a1 LOGIN u <S>" end': 'msg "a1 LOGIN [redatto]" end',
    'a1 LOGIN {4}\r\nuser {6}\r\n<S>': 'a1 LOGIN [redatto]',
  };
  for (final MapEntry(key: input, value: expected) in table.entries) {
    test('no fragment survives: $input', () {
      final out = _redact(input);
      expect(out, isNot(contains(fakeMarker)));
      expect(out, fillSecrets(expected));
    });
  }

  test('token and secret fields are redacted, in JSON, forms and query strings', () {
    final out = _redact(
      '{"<AT>": "<S>.x", "<RT>":"<R><S2>", "expires_in": 3599} '
      'grant_type=<RT>&<RT>=<S3>&<CS>=<S> '
      'https://x.test/cb?code=<S2>&state=ok <PW>=<S3> <PWD>: "<S> <S2>"',
    );
    expect(out, isNot(contains(fakeMarker)));
    expect(out, contains('"expires_in": 3599'));
    expect(out, contains('state=ok'));
    expect(out, contains(fillSecrets('grant_type=<RT>')));
  });

  test('bare Google tokens are redacted wherever they appear', () {
    final out = _redact('word <G><S>-abc_DEF and <R>03<S2>-AbC_dEf in the text');
    expect(out, isNot(contains(fakeMarker)));
  });

  test('IMAP LOGIN and AUTHENTICATE lines lose their credentials', () {
    final out = _redact('a1 LOGIN "user@example.com" "<S>-123"\na2 AUTHENTICATE XOAUTH2 <S2>');
    expect(out, isNot(contains(fakeMarker)));
    expect(out, contains('LOGIN [redatto]'));
    expect(out, contains('AUTHENTICATE XOAUTH2 [redatto]'));
  });

  test('subjects and addresses stay', () {
    const text = '[sync] gmail:mario.rossi@example.com: failed, Oggetto «Fattura di ottobre» da anna@example.org';
    expect(redactSecrets(text), text);
  });

  test('an escaped quote or a space never lets part of a secret through', () {
    final out = _redact(r'a1 LOGIN "u" "pa\"<S>" {"<PW>":"prefix\"<S2>"} {<PW>: first <S3>, user: u}');
    expect(out, isNot(contains(fakeMarker)));
    expect(out, contains('user: u'));
  });

  test('ordinary words keep the address and the status: only the IMAP command and the OAuth parameter go', () {
    const text = 'Login to mario@example.com failed, HttpException: status code: 401';
    expect(redactSecrets(text), text);
  });
}
