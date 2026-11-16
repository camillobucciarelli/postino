import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/result.dart';
import '../../../core/domain/settings_sync_control.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'pairing_scan_area.dart';
import 'qr_camera.dart';

/// «Abbina questo dispositivo» (ADR 0019): the codice di abbinamento typed or pasted, or read from the QR with the
/// camera where there is one («Inquadra il QR», #321); both go through the same [SettingsSyncControl.pair]. The key is
/// kept only once it opened the file on Drive; a wrong code, offline, or no file to pair with say why and keep the
/// dialog open, the camera scanning. True once paired; Esc and «Annulla» answer false.
Future<bool> showPairingEntry(BuildContext context) async =>
    await showPostinoDialog<bool>(
      context,
      title: context.t.impostazioni.syncPairEnterTitle,
      cancelValue: false,
      child: const _PairingEntry(),
    ) ??
    false;

class const _PairingEntry() extends StatefulWidget {
  @override
  State<_PairingEntry> createState() => _PairingEntryState();
}

class _PairingEntryState() extends State<_PairingEntry> {
  final _code = TextEditingController();
  var _busy = false;
  var _scanning = false;
  String? _error;

  /// The last text the camera read that did not pair: it keeps reading it, and is not sent again.
  String? _refused;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair(String code) async {
    if (_busy) return;
    final scanned = _scanning;
    if (scanned && code == _refused) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await GetIt.I<SettingsSyncControl>().pair(code);
    if (!mounted) return;
    final t = context.t.impostazioni;
    if (result is Ok) return Navigator.of(context).pop(true);
    setState(() {
      _busy = false;
      // Switched to the other way in meanwhile: this answer is not about what is on screen.
      if (scanned != _scanning) return;
      if (scanned) _refused = code;
      _error = switch (result) {
        Err(failure: PairingCodeFailure()) => scanned ? t.syncPairScanInvalid : t.syncPairInvalid,
        Err(failure: NothingToPairFailure()) => t.syncPairNothing,
        Err(failure: OfflineFailure()) => t.syncOffline,
        Err(:final failure) => t.syncPairFailed(reason: '$failure'),
        Ok() => null,
      };
    });
  }

  void _switch({required bool scanning}) => setState(() {
    _scanning = scanning;
    _error = null;
    _refused = null;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
        if (_scanning)
          PairingScanArea(onCode: _pair, error: _error)
        else ...[
          PostinoSelectable(
            child: Text(t.syncPairEnterBody, style: PostinoText.body.copyWith(color: context.pc.ink)),
          ),
          PostinoTextField(
            key: const ValueKey('pairing-entry'),
            label: t.syncPairEnterField,
            helper: t.syncPairEnterHelper,
            error: _error,
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            onSubmitted: _pair,
          ),
        ],
        if (_busy)
          PostinoBanner(
            tone: PostinoBannerTone.info,
            title: t.syncPairBusy,
            leading: PostinoSpinner(label: t.syncPairBusy),
            spaced: false,
          ),
        PostinoDialogActions(
          children: [
            PostinoButton(
              label: t.syncPairEnterCancel,
              variant: PostinoButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            if (_scanning)
              PostinoButton(
                key: const ValueKey('pairing-entry-type'),
                label: t.syncPairType,
                autofocus: true,
                onPressed: () => _switch(scanning: false),
              )
            else ...[
              if (GetIt.I<QrCamera>().available)
                PostinoButton(
                  key: const ValueKey('pairing-entry-scan'),
                  label: t.syncPairScan,
                  variant: PostinoButtonVariant.ghost,
                  onPressed: _busy ? null : () => _switch(scanning: true),
                ),
              PostinoButton(
                key: const ValueKey('pairing-entry-confirm'),
                label: t.syncPairEnterConfirm,
                onPressed: _busy ? null : () => _pair(_code.text),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
