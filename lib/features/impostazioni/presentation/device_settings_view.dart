import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/app_updater.dart';
import '../../../core/domain/immediate_notifications_use_case.dart';
import '../../../core/domain/launch_at_login_use_case.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'escape_to_go_back.dart';
import 'immediate_notifications_row.dart';
import 'notification_actions_sections.dart';
import 'notification_permission_row.dart';

/// The Impostazioni del dispositivo (spec #28, story 98): the avvio al login, on desktop (#38), «Cerca
/// aggiornamenti» where Postino updates itself (macOS, #122), then on every platform the «Notifiche», the Notifiche
/// immediate on Android (#214) and the Azioni of a notification (#211).
/// Esc and the back arrow call [onBack]; routing is the caller's.
class const DeviceSettingsView({super.key, required final VoidCallback onBack}) extends StatefulWidget {
  @override
  State<DeviceSettingsView> createState() => _DeviceSettingsViewState();
}

class _DeviceSettingsViewState() extends State<DeviceSettingsView> {
  final _launchAtLogin = GetIt.I<LaunchAtLoginUseCase>();
  final _updater = GetIt.I<AppUpdater>();
  final _immediate = GetIt.I<ImmediateNotificationsUseCase>().supported;

  /// What the OS says; null while it is asked (the switch waits disabled).
  bool? _enabled;

  /// The OS refused the last change.
  var _failed = false;

  @override
  void initState() {
    super.initState();
    if (_launchAtLogin.supported) unawaited(_read());
  }

  Future<void> _read() async {
    bool enabled;
    try {
      enabled = await _launchAtLogin.isEnabled();
    } on Object catch (_) {
      enabled = false;
    }
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _set({required bool enabled}) async {
    setState(() {
      _enabled = null;
      _failed = false;
    });
    try {
      await _launchAtLogin.setEnabled(enabled: enabled);
    } on Object catch (_) {
      _failed = true;
    }
    // The OS has the last word: it may need the user's approval, or have refused.
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    final enabled = _enabled;
    return EscapeToGoBack(
      onBack: widget.onBack,
      child: PostinoSinglePaneLayout(
        appBar: PostinoAppBar(title: t.device, onBack: widget.onBack),
        body: ListView(
          children: [
            if (_launchAtLogin.supported)
              PostinoSwitchRow(
                key: const ValueKey('launch-at-login'),
                title: t.launchAtLogin,
                description: _failed ? t.launchAtLoginFailed : t.launchAtLoginBody,
                value: enabled ?? false,
                onChanged: enabled == null ? null : (v) => unawaited(_set(enabled: v)),
              ),
            if (_updater.supported)
              PostinoSettingsItem(
                key: const ValueKey('check-for-updates'),
                title: t.checkForUpdates,
                subtitle: t.checkForUpdatesBody,
                onTap: () => unawaited(_updater.checkForUpdates()),
              ),
            const NotificationPermissionRow(),
            if (_immediate) const ImmediateNotificationsRow(),
            const NotificationActionsSections(),
          ],
        ),
      ),
    );
  }
}
