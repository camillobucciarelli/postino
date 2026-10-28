import 'account.dart';
import 'result.dart';

abstract interface class AccountsRepository {
  /// Every Account, by position; re-emits after each change.
  Stream<List<Account>> watchAccounts();

  /// Google consent; creates the Gmail Account, or brings it back to attivo if Da ricollegare, then syncs.
  Future<Result<Account>> connectGmail({String? loginHint});
}
