import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/result.dart';

/// Graph answers a throttled request with 429, or 503 when the mailbox is busy; both come with `Retry-After`.
bool graphThrottled(http.Response r) => r.statusCode == 429 || r.statusCode == 503;

/// The `error.code` of a Graph error body (`ErrorItemNotFound`, `SyncStateNotFound`...), else null.
String? graphErrorCode(String body) {
  try {
    final error = (jsonDecode(body) as Map<String, dynamic>)['error'];
    return error is Map<String, dynamic> ? error['code'] as String? : null;
  } on Object catch (_) {
    return null;
  }
}

/// The [Failure] of a Graph answer that is not a success, the token already refreshed once: a 401 is
/// [AuthFailure]; a message gone or an expired delta (410, or a sync state Graph no longer knows) is
/// [NotFoundFailure], so the core redoes the initial sync; a throttled one, after its retry, [RateLimitFailure].
/// Only the path, the status and Graph's error code in the message: never the token, the query or the body.
Failure graphFailure(http.Response r, String path, {DateTime? retryAfter}) {
  final code = graphErrorCode(r.body);
  final lower = code?.toLowerCase();
  return switch (r.statusCode) {
    401 => const AuthFailure(),
    404 || 410 => const NotFoundFailure(),
    _ when lower == 'syncstatenotfound' || lower == 'syncstateinvalid' => const NotFoundFailure(),
    _ when graphThrottled(r) => RateLimitFailure(retryAfter: retryAfter),
    _ => UnexpectedFailure('Graph $path: HTTP ${r.statusCode}${code == null ? '' : ' $code'}'),
  };
}
