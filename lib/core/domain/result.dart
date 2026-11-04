/// Outcome of an operation that can fail: [Ok] with a value or [Err] with a [Failure].
sealed class Result<T> {
  const Result();
}

/// Esito riuscito.
final class Ok<T> extends Result<T> {
  /// Crea un esito riuscito con [value].
  const Ok(this.value);

  /// Il valore prodotto.
  final T value;
}

/// Esito fallito.
final class Err<T> extends Result<T> {
  /// Crea un esito fallito con [failure].
  const Err(this.failure);

  /// Il motivo del fallimento.
  final Failure failure;
}

/// Every known way an operation can fail. Sealed so `switch` stays exhaustive.
sealed class Failure {
  const Failure();
}

// ponytail: single catch-all variant; add specific failures (network, auth, ...) with the first feature that needs them.
/// Errore imprevisto, non classificato altrimenti.
final class UnexpectedFailure extends Failure {
  /// Crea il fallimento con l'[error] originale e, se c'è, il suo stack trace.
  const UnexpectedFailure(this.error, [this.stackTrace]);

  /// L'errore catturato.
  final Object error;

  /// Lo stack trace dell'errore, se disponibile.
  final StackTrace? stackTrace;

  @override
  String toString() => 'UnexpectedFailure($error)';
}

/// The Provider no longer accepts the Account's credentials: the Account becomes Da ricollegare.
final class AuthFailure extends Failure {
  /// Crea il fallimento.
  const AuthFailure();
}

/// The user did not grant the Gmail permission (Google's granular consent let them untick it).
final class MissingPermissionFailure extends Failure {
  /// Crea il fallimento.
  const MissingPermissionFailure();
}

/// No network, or the Provider is unreachable.
final class OfflineFailure extends Failure {
  /// Crea il fallimento.
  const OfflineFailure();
}

/// The message, attachment or draft does not exist on the Provider.
final class NotFoundFailure extends Failure {
  /// Crea il fallimento.
  const NotFoundFailure();
}

/// A Bozza of reply written elsewhere: saving it here would drop In-Reply-To, References and the thread.
final class DraftReplyFailure extends Failure {
  /// Crea il fallimento.
  const DraftReplyFailure();
}

/// A Bozza written elsewhere has attachments: Postino cannot keep them when it saves, so it does not open it.
final class DraftWithAttachmentsFailure extends Failure {
  /// Crea il fallimento.
  const DraftWithAttachmentsFailure();
}

/// The message is bigger than the Provider accepts ([limitBytes], the whole RFC 5322 text).
final class SizeLimitFailure extends Failure {
  /// Crea il fallimento con il limite [limitBytes].
  const SizeLimitFailure(this.limitBytes);

  /// Dimensione massima accettata, in byte.
  final int limitBytes;
}

/// The Provider refused the request for good (HTTP 400, e.g. an invalid header): retrying cannot help.
final class RejectedFailure extends Failure {
  /// Crea il fallimento con il [reason] dato dal Provider.
  const RejectedFailure(this.reason);

  /// Il motivo del rifiuto.
  final String reason;
}

/// The Provider asks to slow down.
final class RateLimitFailure extends Failure {
  /// Crea il fallimento; [retryAfter] è opzionale.
  const RateLimitFailure({this.retryAfter});

  /// When the Provider says the block ends, if it does.
  final DateTime? retryAfter;

  @override
  String toString() => 'RateLimitFailure(retryAfter: $retryAfter)';
}

/// The app is missing a build-time setting (for example the OAuth client ID).
final class ConfigurationFailure extends Failure {
  /// Crea il fallimento per l'impostazione [setting] mancante.
  const ConfigurationFailure(this.setting);

  /// Nome dell'impostazione mancante.
  final String setting;
}

/// The user backed out (for example closed the consent page).
final class CancelledFailure extends Failure {
  /// Crea il fallimento.
  const CancelledFailure();
}

/// Reconnecting an Account, the user picked another Google identity than [expected].
final class WrongAccountFailure extends Failure {
  /// Crea il fallimento con l'indirizzo [expected] atteso.
  const WrongAccountFailure(this.expected);

  /// L'indirizzo dell'Account che si stava ricollegando.
  final String expected;
}
