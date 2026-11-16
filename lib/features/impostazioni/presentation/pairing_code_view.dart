import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/settings_sync_control.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'pairing_code_panel.dart';

/// «Abbina un altro dispositivo» (ADR 0019): the QR and the codice di abbinamento of this device's key, opened only by
/// this explicit action. It closes by itself after `pairingCodeShownFor` and when the app goes to the background, and
/// asks the platform to keep it out of captures (`ScreenGuard`); on iOS the code hides while the screen is recorded.
/// The code is selectable and read by the screen reader character by character, group by group.
/// One at a time: closing a second one would turn the protection off under the first.
Future<void> showPairingCode(BuildContext context) async {
  if (_showing) return;
  _showing = true;
  try {
    final code = await GetIt.I<SettingsSyncControl>().pairingCode();
    if (!context.mounted) return;
    await showPostinoDialog<void>(
      context,
      title: context.t.impostazioni.syncPairOther,
      child: PairingCodePanel(code: code),
    );
  } finally {
    _showing = false;
  }
}

var _showing = false;
