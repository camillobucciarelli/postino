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

  @override
  String toString() => 'UnexpectedFailure($error)';
}

/// The Provider no longer accepts the Account's credentials: the Account becomes Da ricollegare.
final class AuthFailure extends Failure {
  const AuthFailure();
}

/// The user did not grant the Gmail permission (Google's granular consent let them untick it).
final class MissingPermissionFailure extends Failure {
  const MissingPermissionFailure();
}

/// No network, or the Provider is unreachable.
final class OfflineFailure extends Failure {
  const OfflineFailure();
}

/// The message, attachment or draft does not exist on the Provider.
final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// A Bozza of reply written elsewhere: saving it here would drop In-Reply-To, References and the thread.
final class DraftReplyFailure extends Failure {
  const DraftReplyFailure();
}

/// A Bozza written elsewhere has attachments: Postino cannot keep them when it saves, so it does not open it.
final class DraftWithAttachmentsFailure extends Failure {
  const DraftWithAttachmentsFailure();
}

/// The message is bigger than the Provider accepts ([limitBytes], the whole RFC 5322 text).
final class SizeLimitFailure extends Failure {
  const SizeLimitFailure(this.limitBytes);
  final int limitBytes;
}

/// The Provider refused the request for good (HTTP 400, e.g. an invalid header): retrying cannot help.
final class RejectedFailure extends Failure {
  const RejectedFailure(this.reason);
  final String reason;
}

/// The Provider asks to slow down.
final class RateLimitFailure extends Failure {
  const RateLimitFailure({this.retryAfter});

  /// When the Provider says the block ends, if it does.
  final DateTime? retryAfter;

  @override
  String toString() => 'RateLimitFailure(retryAfter: $retryAfter)';
}

/// The app is missing a build-time setting (for example the OAuth client ID).
final class ConfigurationFailure extends Failure {
  const ConfigurationFailure(this.setting);
  final String setting;
}

/// The user backed out (for example closed the consent page).
final class CancelledFailure extends Failure {
  const CancelledFailure();
}

/// Reconnecting an Account, the user picked another Google identity than [expected].
final class WrongAccountFailure extends Failure {
  const WrongAccountFailure(this.expected);
  final String expected;
}
