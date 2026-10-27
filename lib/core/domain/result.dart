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
