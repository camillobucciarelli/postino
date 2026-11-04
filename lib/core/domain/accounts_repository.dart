import 'account.dart';
import 'result.dart';

/// Gli Account collegati: elenco e collegamento.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class AccountsRepository() {
  /// Every Account, by position; re-emits after each change.
  Stream<List<Account>> watchAccounts();

  /// Google consent; creates the Gmail Account, or brings it back to attivo if Da ricollegare, then syncs.
  /// [loginHint] is the address of the Account being reconnected: it preselects it and the grant must match it
  /// (else [WrongAccountFailure], nothing written).
  Future<Result<Account>> connectGmail({String? loginHint});
}
