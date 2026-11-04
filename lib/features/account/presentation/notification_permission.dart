import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/notifications.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// After the first Account (#39): says what the notifications show, then lets the OS ask. Nothing where the OS
/// need not ask (Windows, Linux, Android before 13) or already allowed them.
Future<void> askNotificationPermission(BuildContext context) async {
  final notifications = GetIt.I<Notifications>();
  if (!await notifications.permissionNeeded() || !context.mounted) return;
  final t = context.t.notifiche;
  final go = await showPostinoConfirmDialog(
    context,
    title: t.permissionTitle,
    message: t.permissionBody,
    confirmLabel: t.permissionAllow,
    cancelLabel: t.permissionLater,
  );
  if (go) await notifications.requestPermission();
}
