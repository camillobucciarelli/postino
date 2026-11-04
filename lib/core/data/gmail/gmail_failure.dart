import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/result.dart';

/// A failed Gmail call, unwound to [gmailGuard].
final class const GmailFailed(final Failure failure) implements Exception {}

/// Adapters never throw: no network is [OfflineFailure], anything else [UnexpectedFailure].
Future<Result<T>> gmailGuard<T>(Future<Result<T>> Function() body) async {
  try {
    return await body();
  } on GmailFailed catch (e) {
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
