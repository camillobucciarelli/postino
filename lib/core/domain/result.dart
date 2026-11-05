/// Outcome of an operation that can fail: [Ok] with a value or [Err] with a [Failure].
sealed class const Result<T>() {
  /// Costruttore delle varianti.
  this;
}

/// Esito riuscito.
final class const Ok<T>(
  /// Il valore prodotto.
  final T value,
) extends Result<T> {
  /// Crea un esito riuscito con [value].
  this;
}

/// Esito fallito.
final class const Err<T>(
  /// Il motivo del fallimento.
  final Failure failure,
) extends Result<T> {
  /// Crea un esito fallito con [failure].
  this;
}

/// Every known way an operation can fail. Sealed so `switch` stays exhaustive.
sealed class const Failure() {
  /// Costruttore delle varianti.
  this;
}

// ponytail: single catch-all variant; add specific failures (network, auth, ...) with the first feature that needs them.
/// Errore imprevisto, non classificato altrimenti.
final class const UnexpectedFailure(
  /// L'errore catturato.
  final Object error, [

  /// Lo stack trace dell'errore, se disponibile.
  final StackTrace? stackTrace,
]) extends Failure {
  /// Crea il fallimento con l'[error] originale e, se c'è, il suo stack trace.
  this;

  @override
  String toString() => 'UnexpectedFailure($error)';
}

/// The Provider no longer accepts the Account's credentials: the Account becomes Da ricollegare.
final class const AuthFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The user did not grant the Gmail permission (Google's granular consent let them untick it).
final class const MissingPermissionFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// No network, or the Provider is unreachable.
final class const OfflineFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The message, attachment or draft does not exist on the Provider.
final class const NotFoundFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// A Bozza of reply written elsewhere: saving it here would drop In-Reply-To, References and the thread.
final class const DraftReplyFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// A Bozza written elsewhere has attachments: Postino cannot keep them when it saves, so it does not open it.
final class const DraftWithAttachmentsFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The message is bigger than the Provider accepts ([limitBytes], the whole RFC 5322 text).
final class const SizeLimitFailure(
  /// Dimensione massima accettata, in byte.
  final int limitBytes,
) extends Failure {
  /// Crea il fallimento con il limite [limitBytes].
  this;
}

/// The Provider refused the request for good (HTTP 400, e.g. an invalid header): retrying cannot help.
final class const RejectedFailure(
  /// Il motivo del rifiuto.
  final String reason,
) extends Failure {
  /// Crea il fallimento con il [reason] dato dal Provider.
  this;
}

/// The Provider asks to slow down.
final class const RateLimitFailure({
  /// When the Provider says the block ends, if it does.
  final DateTime? retryAfter,
}) extends Failure {
  /// Crea il fallimento; [retryAfter] è opzionale.
  this;

  @override
  String toString() => 'RateLimitFailure(retryAfter: $retryAfter)';
}

/// The app is missing a build-time setting (for example the OAuth client ID).
final class const ConfigurationFailure(
  /// Nome dell'impostazione mancante.
  final String setting,
) extends Failure {
  /// Crea il fallimento per l'impostazione [setting] mancante.
  this;
}

/// A downloaded file does not match its expected hash: it was discarded.
final class const IntegrityFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The user backed out (for example closed the consent page).
final class const CancelledFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// Reconnecting an Account, the user picked another Google identity than [expected].
final class const WrongAccountFailure(
  /// L'indirizzo dell'Account che si stava ricollegando.
  final String expected,
) extends Failure {
  /// Crea il fallimento con l'indirizzo [expected] atteso.
  this;
}

/// Drive refused the file of the Impostazioni di Postino for lack of the `drive.appdata` scope, or the user did
/// not grant it at the incremental consent: only that consent fixes it. Not an [AuthFailure]: the Account's mail still works and it never becomes
/// Da ricollegare.
final class const DriveScopeFailure() extends Failure {
  /// Crea il fallimento.
  this;
}
