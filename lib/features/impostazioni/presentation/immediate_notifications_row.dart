import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/immediate_notifications_use_case.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'listening_notice.dart';

/// Impostazioni del dispositivo › «Notifiche immediate» (#214, story 88 and 98): Android only, off by default, with
/// its price in the description. On starts the service and asks for the battery exemption; off stops it.
class const ImmediateNotificationsRow({super.key}) extends StatefulWidget {
  @override
  State<ImmediateNotificationsRow> createState() => _ImmediateNotificationsRowState();
}

class _ImmediateNotificationsRowState() extends State<ImmediateNotificationsRow> {
  final _useCase = GetIt.I<ImmediateNotificationsUseCase>();

  /// The choice remembered; null while read or changed (the switch waits disabled).
  bool? _enabled;

  /// The OS refused the last change.
  var _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    bool enabled;
    try {
      enabled = await _useCase.isEnabled();
    } on Object catch (_) {
      enabled = false;
    }
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _set({required bool enabled}) async {
    final notice = listeningNotice(context.t);
    setState(() {
      _enabled = null;
      _failed = false;
    });
    try {
      await _useCase.setEnabled(enabled: enabled, notice: notice);
    } on Object catch (_) {
      _failed = true;
    }
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    final enabled = _enabled;
    return PostinoSwitchRow(
      key: const ValueKey('immediate-notifications'),
      title: t.immediateNotifications,
      description: _failed ? t.immediateNotificationsFailed : t.immediateNotificationsBody,
      value: enabled ?? false,
      onChanged: enabled == null ? null : (v) => unawaited(_set(enabled: v)),
    );
  }
}
