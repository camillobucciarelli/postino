import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';

/// Adapters never throw: no network is [OfflineFailure], anything else [UnexpectedFailure].
Future<Result<T>> googleGuard<T>(Future<Result<T>> Function() body) async {
  try {
    return await body();
  } on OAuthFailed catch (e) {
    return Err(e.failure);
  } on http.RequestAbortedException {
    return const Err(CancelledFailure());
  } on http.ClientException {
    return const Err(OfflineFailure());
  } on TimeoutException {
    return const Err(OfflineFailure());
  } on Object catch (e, s) {
    return Err(UnexpectedFailure(e, s));
  }
}

/// A Google API answers a quota hit with 429, or with 403 and a rate-limit reason.
bool googleRateLimited(http.Response r) =>
    r.statusCode == 429 || (r.statusCode == 403 && r.body.contains('ateLimitExceeded'));

/// A 403 because the token lacks the API's scope: only a new consent fixes it.
bool googleScopeMissing(http.Response r) =>
    r.statusCode == 403 &&
    (r.body.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') || r.body.contains('insufficientPermissions'));
