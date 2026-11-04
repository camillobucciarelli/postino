import 'package:injectable/injectable.dart';

import 'launch_at_login.dart';
import 'settings_repository.dart';

/// Avvio al login, on by default (#38): the OS holds whether it is on, the Impostazioni del dispositivo remember
/// that the default was applied, so a later choice (here or in the system's settings) is never overridden.
@injectable
class LaunchAtLoginUseCase(final LaunchAtLogin _os, final SettingsRepository _settings) {
  /// Lega il servizio del sistema alle Impostazioni del dispositivo.
  this;

  /// Whether this device can start Postino at login.
  bool get supported => _os.supported;

  /// At startup: the first run turns it on. A failure leaves the default for the next run.
  Future<void> applyDefault() async {
    if (!_os.supported || await _settings.launchAtLogin() != null) return;
    await setEnabled(enabled: true);
  }

  /// Whether the OS starts Postino at login now.
  Future<bool> isEnabled() => _os.isEnabled();

  /// The switch in the Impostazioni del dispositivo: the OS first, then the choice is remembered.
  Future<void> setEnabled({required bool enabled}) async {
    await _os.setEnabled(enabled: enabled);
    await _settings.setLaunchAtLogin(enabled: enabled);
  }
}
