import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/auto_label.dart';
import '../../../core/domain/auto_labels_repository.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/model_download.dart';
import '../../../core/domain/model_download_state.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../core/presentation/model_download_banner.dart';
import '../../../core/presentation/model_download_confirm.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'auto_label_tile.dart';
import 'create_label_dialog.dart';
import 'escape_to_go_back.dart';

/// Impostazioni › Account › Etichette automatiche (#107): what the feature does, the state of the model,
/// the Etichette of [accountId] with their «Automatica» switch, and «Crea Etichetta».
/// Routing is the caller's: Esc and the back arrow call [onBack].
class const AutoLabelsView({super.key, required final String accountId, required final VoidCallback onBack})
    extends StatefulWidget {
  @override
  State<AutoLabelsView> createState() => _AutoLabelsViewState();
}

class _AutoLabelsViewState() extends State<AutoLabelsView> with AccountsSignal {
  late final _labels = streamSignal(() => GetIt.I<InboxRepository>().watchLabels(widget.accountId));
  late final _config = streamSignal(() => GetIt.I<AutoLabelsRepository>().watch(widget.accountId));
  late final StreamSubscription<ModelDownloadState> _model;
  var _asked = false;

  @override
  void initState() {
    super.initState();
    // The first activation on cellular waits for the answer to the dialog, wherever it was turned on.
    _model = GetIt.I<ModelDownload>().watch().listen((state) {
      if (state is ModelDownloadAwaitingConfirmation && !_asked && mounted) {
        _asked = true;
        unawaited(confirmModelDownload(context, state.sizeBytes).whenComplete(() => _asked = false));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_model.cancel());
    _labels.dispose();
    _config.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EscapeToGoBack(
    onBack: widget.onBack,
    child: SignalBuilder(
      builder: (context) {
        final t = context.t.etichetteAutomatiche;
        final account = (accounts.value.value ?? const <Account>[]).where((a) => a.id == widget.accountId).firstOrNull;
        final labels = [
          for (final l in _labels.value.value ?? const <Label>[])
            if (l.kind == LabelKind.etichetta) l,
        ];
        final config = _config.value.value ?? const <String, AutoLabel>{};
        return PostinoSettingsPage(
          title: t.title,
          subtitle: account == null ? null : t.page(account: account.name),
          account: account == null
              ? null
              : (color: PostinoAccountColor.values[account.color], initial: account.initial),
          onBack: widget.onBack,
          intro: t.intro,
          sections: [
            const Padding(
              padding: EdgeInsets.only(top: PostinoSpacing.s4),
              child: ModelDownloadBanner(showReady: true, spaced: false),
            ),
            PostinoSettingsSection(
              title: t.labels,
              children: [
                if (labels.isEmpty)
                  PostinoSelectable(
                    child: Text(t.empty, style: PostinoText.preview.copyWith(color: context.pc.inkMuted)),
                  ),
                for (final l in labels)
                  AutoLabelTile(
                    key: ValueKey('auto-label-${l.id}'),
                    accountId: widget.accountId,
                    label: l,
                    config: config[l.id] ?? autoLabelDefault,
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PostinoButton(
                    label: t.create,
                    variant: PostinoButtonVariant.ghost,
                    onPressed: () => unawaited(
                      showCreateLabelDialog(context, widget.accountId, [
                        for (final l in _labels.value.value ?? const <Label>[]) l.name,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
