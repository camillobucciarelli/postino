import 'dart:convert';

import 'package:http/http.dart' as http;

/// A Google API answers a quota hit with 429, or with 403 and a rate-limit reason.
bool googleRateLimited(http.Response r) =>
    r.statusCode == 429 || (r.statusCode == 403 && r.body.contains('ateLimitExceeded'));

/// A 403 because the token lacks the API's scope: only a new consent fixes it.
bool googleScopeMissing(http.Response r) =>
    r.statusCode == 403 &&
    (r.body.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') || r.body.contains('insufficientPermissions'));

/// Why a Google API refused the call (#317): `error.errors[0].reason`, else `error.details[0].reason`, else
/// `error.status`; `accessNotConfigured` or `SERVICE_DISABLED` when the API is off in the Cloud project. Only a
/// code-like word, never the message: null otherwise.
String? googleReason(http.Response r) {
  final Object? json;
  try {
    json = jsonDecode(r.body);
  } on FormatException {
    return null;
  }
  final reason = switch (json) {
    {'error': {'errors': [{'reason': final String reason}, ...]}} => reason,
    {'error': {'details': [{'reason': final String reason}, ...]}} => reason,
    {'error': {'status': final String status}} => status,
    _ => null,
  };
  return reason != null && RegExp(r'^\w{1,64}$').hasMatch(reason) ? reason : null;
}
