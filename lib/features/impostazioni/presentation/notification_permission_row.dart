import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/notifications.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// Impostazioni del dispositivo › «Notifiche» (#211, rest of story 93): whether the OS allows them; when not,
/// «Consenti» asks the OS, and where it no longer asks (iOS asks once, Android after two refusals) opens Postino's
/// notifications in the system settings. Read again when the app comes back from there.
class const NotificationPermissionRow({super.key}) extends StatefulWidget {
  @override
  State<NotificationPermissionRow> createState() => _NotificationPermissionRowState();
}

class _NotificationPermissionRowState() extends State<NotificationPermissionRow> {
  final _notifications = GetIt.I<Notifications>();
  late final AppLifecycleListener _lifecycle;

  /// Null while the OS is asked.
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_read()));
    unawaited(_read());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    bool allowed;
    try {
      allowed = !await _notifications.permissionNeeded();
    } on Object catch (_) {
      allowed = false;
    }
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _allow() async {
    try {
      if (!await _notifications.requestPermission()) await _notifications.openSystemSettings();
    } on Object catch (_) {
      // The OS refused to ask or to open its settings: the row says what it says now.
    }
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    final allowed = _allowed;
    return PostinoSettingsItem(
      key: const ValueKey('notifications-permission'),
      title: t.notifications,
      subtitle: switch (allowed) {
        true => t.notificationsAllowed,
        false => t.notificationsDenied,
        null => null,
      },
      onTap: null,
      trailing: allowed == false
          ? PostinoButton(
              key: const ValueKey('notifications-allow'),
              label: t.notificationsAllow,
              variant: PostinoButtonVariant.ghost,
              onPressed: () => unawaited(_allow()),
            )
          : null,
    );
  }
}
