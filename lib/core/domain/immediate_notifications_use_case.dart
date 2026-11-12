import 'package:injectable/injectable.dart';

import 'immediate_notifications.dart';
import 'settings_repository.dart';

/// The switch of the Notifiche immediate (#214), off by default: the Impostazioni del dispositivo remember the choice,
/// the service follows it. The periodic check (#212) stays scheduled either way, a safety net if the system kills the
/// service: with the service alive the app owns the sync and the check only asks it.
@injectable
class ImmediateNotificationsUseCase(final ImmediateNotifications _os, final SettingsRepository _settings) {
  /// Lega il servizio del sistema alle Impostazioni del dispositivo.
  this;

  /// Whether this device has Notifiche immediate (Android).
  bool get supported => _os.supported;

  /// The choice remembered; off until chosen.
  Future<bool> isEnabled() async => _os.supported && (await _settings.immediateNotifications() ?? false);

  /// On: the service first, then the battery exemption, then the choice is remembered; a refusal of the OS throws
  /// before anything is remembered. Off: the service stops and the choice is remembered.
  Future<void> setEnabled({required bool enabled, required ListeningNotice notice}) async {
    if (enabled) {
      await _os.start(notice);
      await _os.requestBatteryExemption();
    } else {
      await _os.stop();
    }
    await _settings.setImmediateNotifications(enabled: enabled);
  }

  /// At every start of the app: the service again when on (killed, or the notification's texts in a new language).
  Future<void> resume(ListeningNotice notice) async {
    if (await isEnabled()) await _os.start(notice);
  }
}
