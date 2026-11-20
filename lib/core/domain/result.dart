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

  /// The variant's name, as the error log shows it (#116); variants with data add it.
  @override
  String toString() => '$runtimeType';
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
final class const AuthFailure({
  /// Why the Provider refused, for the error log (#353): never tokens, addresses nor the Provider's free text.
  final String? reason,
}) extends Failure {
  /// Crea il fallimento; [reason] è opzionale.
  this;

  @override
  String toString() => reason == null ? 'AuthFailure' : 'AuthFailure($reason)';
}

/// The user did not grant the Gmail permission (Google's granular consent let them untick it).
final class const MissingPermissionFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// No network, or the Provider is unreachable.
final class const OfflineFailure({
  /// Which request did not get through and how (#252), for the error log: never ids, addresses nor URLs.
  final String? detail,

  /// The Provider took the request, then stopped answering (#252): the network is there, this request is stuck.
  final bool stalled = false,
}) extends Failure {
  /// Crea il fallimento; [detail] e [stalled] sono opzionali.
  this;

  @override
  String toString() => detail == null ? 'OfflineFailure' : 'OfflineFailure($detail)';
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

  @override
  String toString() => 'SizeLimitFailure($limitBytes)';
}

/// The Provider refused the request for good (HTTP 400, e.g. an invalid header): retrying cannot help.
final class const RejectedFailure(
  /// Il motivo del rifiuto.
  final String reason,
) extends Failure {
  /// Crea il fallimento con il [reason] dato dal Provider.
  this;

  @override
  String toString() => 'RejectedFailure($reason)';
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

  @override
  String toString() => 'ConfigurationFailure($setting)';
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

/// Reconnecting an Account, the user picked another identity than [expected].
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

/// Autodiscovery found no servers for the address of a password Account: the user enters them by hand.
final class const ServerNotFoundFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The Account (same Provider and address) is already attivo: connecting it again would change nothing.
final class const AlreadyConnectedFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// A Gmail address given to the password form: it connects with «Collega Gmail» (OAuth), never with a password.
final class const UseGmailFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// A Microsoft address given to the password form: it connects with «Collega Outlook» (OAuth), never with a password.
final class const UseMicrosoftFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The user's organization lets the app in only after an administrator approves it (Microsoft 365).
final class const AdminConsentFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The policies of the user's organization block the sign-in from this app or this device (Microsoft 365).
final class const OrganizationPolicyFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The file of the Impostazioni on Drive is sealed and this device holds no Chiave di sincronizzazione (ADR 0019):
/// Non abbinato. Nothing is read nor written until it is paired.
final class const SyncNotPairedFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The file of the Impostazioni on Drive is sealed with another key than this device's, after «Rigenera la chiave»
/// on another device or two first encryptions at once (ADR 0019): it must be paired again.
final class const SyncKeyInvalidFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// The codice di abbinamento is malformed or does not open the file: a typo, or the code of a device that syncs on
/// another Account di sincronizzazione (ADR 0019). Nothing was saved.
final class const PairingCodeFailure() extends Failure {
  /// Crea il fallimento.
  this;
}

/// No sealed file on Drive yet, so nothing to pair with: this device makes its own key at its first cycle (ADR 0019).
final class const NothingToPairFailure() extends Failure {
  /// Crea il fallimento.
  this;
}
