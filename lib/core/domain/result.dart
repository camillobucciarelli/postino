/// Outcome of an operation that can fail: [Ok] with a value or [Err] with a [Failure].
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Every known way an operation can fail. Sealed so `switch` stays exhaustive.
sealed class Failure {
  const Failure();
}

// ponytail: single catch-all variant; add specific failures (network, auth, ...) with the first feature that needs them.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}

/// The Provider no longer accepts the Account's credentials: the Account becomes Da ricollegare.
final class AuthFailure extends Failure {
  const AuthFailure();
}

/// No network, or the Provider is unreachable.
final class OfflineFailure extends Failure {
  const OfflineFailure();
}

/// The message, attachment or draft does not exist on the Provider.
final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// The Provider asks to slow down.
final class RateLimitFailure extends Failure {
  const RateLimitFailure();
}
