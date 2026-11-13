import '../../domain/result.dart';

/// A failed call with an OAuth Provider's API (Gmail, Drive, Graph), unwound to the adapter's guard.
final class const OAuthFailed(final Failure failure) implements Exception {}
