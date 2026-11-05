import 'package:injectable/injectable.dart';

import 'accounts_repository.dart';
import 'result.dart';
import 'settings_repository.dart';

/// La voce «Sincronizza su…» (ADR 0016): scegliere un Account chiede prima a Google l'accesso a Drive, e solo
/// se è concesso ricorda la scelta; «Nessuno» spegne la sincronizzazione.
@injectable
class SettingsSyncAccountUseCase(final AccountsRepository _accounts, final SettingsRepository _settings) {
  /// Lega il consenso di Drive alla scelta salvata nelle Impostazioni del dispositivo.
  this;

  /// Sceglie [accountId] (null: Nessuno). Se il consenso fallisce la scelta resta com'era.
  Future<Result<void>> choose(String? accountId) async {
    if (accountId != null) {
      final granted = await _accounts.grantDriveAccess(accountId);
      if (granted case Err()) return granted;
    }
    await _settings.setSettingsSyncAccount(accountId);
    return const Ok(null);
  }
}
