import 'account.dart';
import 'mail_servers.dart';
import 'result.dart';

/// Gli Account collegati: elenco e collegamento.
abstract interface class AccountsRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Every Account, by position; re-emits after each change.
  Stream<List<Account>> watchAccounts();

  /// Google consent; creates the Gmail Account, or brings it back to attivo if Da ricollegare, then syncs.
  /// The same address through another Provider is another Account (ADR 0016), connected beside it.
  /// [loginHint] is the address of the Account being reconnected: it preselects it and the grant must match it
  /// (else [WrongAccountFailure], nothing written).
  Future<Result<Account>> connectGmail({String? loginHint});

  /// Microsoft consent for a personal account (Outlook.com, Hotmail, Live); creates the Microsoft Account, or
  /// brings it back to attivo if Da ricollegare, then syncs. Like [connectGmail], plus [WorkAccountFailure] for a
  /// work or school identity and [MissingPermissionFailure] when the mail permissions were not granted.
  Future<Result<Account>> connectMicrosoft({String? loginHint});

  /// Connects the iCloud or IMAP Account [address] with [password] (an app-specific one for iCloud), or brings it
  /// back to attivo if Da ricollegare, then syncs. The Provider comes from the address (`passwordProviderFor`);
  /// the servers are [servers] when given, else those already saved for the Account, the Provider's preset or
  /// autodiscovery. A test connection runs before anything is written: on any failure nothing is saved.
  /// Failures: [UseGmailFailure] (a Gmail address), [UseMicrosoftFailure] (an Outlook.com, Hotmail, Live or MSN one), [AlreadyConnectedFailure], [ServerNotFoundFailure] (enter the
  /// servers by hand), [AuthFailure] (credentials refused), [OfflineFailure] (server unreachable), and
  /// [CancelledFailure] when [cancel] completes before the save: then nothing is written either.
  Future<Result<Account>> connectWithPassword(
    String address,
    String password, {
    ServerSettings? servers,
    Future<void>? cancel,
  });

  /// Incremental consent for Drive (ADR 0016) on the Gmail Account [accountId], for the Impostazioni di Postino.
  /// On success the new tokens replace the Account's; otherwise nothing is written: [DriveScopeFailure] if the
  /// user did not grant Drive, [WrongAccountFailure] if they picked another Google identity. Never makes the
  /// Account Da ricollegare.
  Future<Result<void>> grantDriveAccess(String accountId);

  /// Rimozione dell'Account [accountId] (#174): its sync and IDLE stop, everything of it is deleted here (messages,
  /// Etichette, Bozze, queued Azioni, which are never sent, and Conflitti) with its credentials in the keychain; a
  /// Gmail refresh token is revoked when online. Nothing changes on the server. Nothing if there is no such Account.
  Future<void> remove(String accountId);
}
