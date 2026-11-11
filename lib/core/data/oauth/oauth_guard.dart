import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/result.dart';
import 'oauth_failed.dart';

/// Adapters never throw: an [OAuthFailed] is its failure, no network is [OfflineFailure], anything else
/// [UnexpectedFailure]. Shared by the HTTP adapters (Gmail, Drive, Graph).
Future<Result<T>> oauthGuard<T>(Future<Result<T>> Function() body) async {
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
