import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/app_updater.dart';
import '../../../core/domain/immediate_notifications_use_case.dart';
import '../../../core/domain/launch_at_login_use_case.dart';
import '../../../core/domain/result.dart';
import '../../../core/presentation/app_update_banner.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'app_version_label.dart';
import 'escape_to_go_back.dart';
import 'immediate_notifications_row.dart';
import 'notification_actions_sections.dart';
import 'notification_permission_row.dart';

/// The Impostazioni del dispositivo (spec #28, story 98): the avvio al login, on desktop (#38), «Cerca
/// aggiornamenti» where Postino looks for updates (Sparkle on macOS, #122; Android and iOS say what they found,
/// #287), then on every platform the «Notifiche», the Notifiche immediate on Android (#214) and the Azioni of a
/// notification (#211).
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

  /// What the last «Cerca aggiornamenti» found; null before it, while it looks, or when it failed (#287: no error
  /// shown).
  UpdateCheck? _check;

  Future<void> _checkForUpdates() async {
    setState(() => _check = null);
    final check = switch (await _updater.checkForUpdates()) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (mounted) setState(() => _check = check);
  }

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
      // The template of every page of the Impostazioni: its column and margins (#312).
      child: PostinoSettingsPage(
        title: t.device,
        onBack: widget.onBack,
        sections: [
          if (_launchAtLogin.supported)
            PostinoSwitchRow(
              key: const ValueKey('launch-at-login'),
              title: t.launchAtLogin,
              description: _failed ? t.launchAtLoginFailed : t.launchAtLoginBody,
              value: enabled ?? false,
              onChanged: enabled == null ? null : (v) => unawaited(_set(enabled: v)),
            ),
          if (_updater.supported) ...[
            // Live: the screen reader hears what the check found.
            Semantics(
              liveRegion: true,
              child: PostinoSettingsItem(
                key: const ValueKey('check-for-updates'),
                title: t.checkForUpdates,
                subtitle: switch (_check) {
                  UpdateCheck.upToDate => t.upToDate,
                  UpdateCheck.available => t.checkFound,
                  UpdateCheck.shown || null => t.checkForUpdatesBody,
                },
                onTap: () => unawaited(_checkForUpdates()),
              ),
            ),
            const AppUpdateBanner(
              padding: EdgeInsets.fromLTRB(PostinoSpacing.s4, PostinoSpacing.s2, PostinoSpacing.s4, 0),
            ),
          ],
          const AppVersionLabel(),
          const NotificationPermissionRow(),
          if (_immediate) const ImmediateNotificationsRow(),
          const NotificationActionsSections(),
        ],
      ),
    );
  }
}
