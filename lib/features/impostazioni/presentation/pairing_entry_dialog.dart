import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/result.dart';
import '../../../core/domain/settings_sync_control.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// «Abbina questo dispositivo» (ADR 0019): the codice di abbinamento typed or pasted (the camera comes with #321's
/// second slice). The key is kept only once it opened the file on Drive; a wrong code, offline, or no file to pair
/// with say why under the field and keep the dialog open. True once paired; Esc and «Annulla» answer false.
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
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await GetIt.I<SettingsSyncControl>().pair(_code.text);
    if (!mounted) return;
    final t = context.t.impostazioni;
    if (result is Ok) return Navigator.of(context).pop(true);
    setState(() {
      _busy = false;
      _error = switch (result) {
        Err(failure: PairingCodeFailure()) => t.syncPairInvalid,
        Err(failure: NothingToPairFailure()) => t.syncPairNothing,
        Err(failure: OfflineFailure()) => t.syncOffline,
        Err(:final failure) => t.syncPairFailed(reason: '$failure'),
        Ok() => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
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
          onSubmitted: (_) => _pair(),
        ),
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
            PostinoButton(
              key: const ValueKey('pairing-entry-confirm'),
              label: t.syncPairEnterConfirm,
              onPressed: _busy ? null : _pair,
            ),
          ],
        ),
      ],
    );
  }
}
