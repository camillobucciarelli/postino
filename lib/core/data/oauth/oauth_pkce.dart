import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 32 random bytes, URL-safe: a PKCE verifier or an OAuth `state`.
String randomUrlSafe() {
  final r = Random.secure();
  return base64Url.encode([for (var i = 0; i < 32; i++) r.nextInt(256)]).replaceAll('=', '');
}

/// The S256 `code_challenge` of a PKCE [verifier].
String pkceChallenge(String verifier) =>
    base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
