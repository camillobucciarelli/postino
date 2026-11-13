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

  /// On: the service, then the choice is remembered, then the battery exemption is asked; a refusal of the OS to
  /// start throws before anything is remembered. Off: the service stops and the choice is remembered.
  Future<void> setEnabled({required bool enabled, required ListeningNotice notice}) async {
    await (enabled ? _os.start(notice) : _os.stop());
    await _settings.setImmediateNotifications(enabled: enabled);
    if (!enabled) return;
    try {
      await _os.requestBatteryExemption();
    } on Object catch (_) {
      // Best effort: the service runs without it, only Doze and the starts from the background are stricter. The
      // switch stays on, as the service does.
    }
  }

  /// At every start of the app's engine: the service again when on (killed by the system), stopped when off, so the
  /// service never outlives a choice the app did not remember (a failure between the two).
  Future<void> resume(ListeningNotice notice) async {
    if (!_os.supported) return;
    await (await isEnabled() ? _os.start(notice) : _os.stop());
  }
}
