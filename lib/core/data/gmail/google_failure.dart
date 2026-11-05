import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/result.dart';

/// A failed Google API call (Gmail, Drive), unwound to [googleGuard].
final class const GoogleFailed(final Failure failure) implements Exception {}

/// Adapters never throw: no network is [OfflineFailure], anything else [UnexpectedFailure].
Future<Result<T>> googleGuard<T>(Future<Result<T>> Function() body) async {
  try {
    return await body();
  } on GoogleFailed catch (e) {
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
