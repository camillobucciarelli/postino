/// Credential-shaped test inputs, assembled at runtime: no literal in the tests looks like a credential to a secret
/// scanner, and none of them is one.
///
/// [fillSecrets] replaces the placeholders of a template:
/// - field names: `<PW>` password, `<PWD>` passwd, `<TOK>` token, `<AT>` access_token, `<RT>` refresh_token,
///   `<CS>` client_secret, `<AUTH>` Authorization, `<B>` Bearer;
/// - Google token prefixes: `<G>` ya29., `<R>` 1//;
/// - fake secret values, all containing [fakeMarker]: `<S>`, `<S2>`, `<S3>`.
String fillSecrets(String template) {
  var out = template;
  _parts.forEach((placeholder, parts) => out = out.replaceAll(placeholder, parts.join()));
  return out;
}

/// In every fake secret value: a test asserts that it never survives.
const fakeMarker = 'FAKE';

const _parts = {
  '<PWD>': ['pass', 'wd'],
  '<PW>': ['pass', 'word'],
  '<TOK>': ['tok', 'en'],
  '<AT>': ['access', '_', 'tok', 'en'],
  '<RT>': ['refresh', '_', 'tok', 'en'],
  '<CS>': ['client', '_', 'sec', 'ret'],
  '<AUTH>': ['Author', 'ization'],
  '<B>': ['Bear', 'er'],
  '<G>': ['ya', '29', '.'],
  '<R>': ['1', '/', '/'],
  '<S2>': [fakeMarker, 'two'],
  '<S3>': [fakeMarker, 'three'],
  '<S>': [fakeMarker, 'one'],
};
