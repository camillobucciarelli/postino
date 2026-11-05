import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../core/domain/auto_labels_repository.dart';
import '../../../core/domain/model_download.dart';

/// The «Automatica» switch of an Etichetta (#107): saved in the Impostazioni di Postino, and the first
/// activation starts the model download (ADR 0015).
@injectable
class AutoLabelSwitchUseCase(final AutoLabelsRepository _labels, final ModelDownload _model) {
  /// Lega la configurazione al download del modello.
  this;

  /// Saves the switch; turning it on starts the download if the model is absent, without waiting for it:
  /// the UI follows [ModelDownload.watch].
  Future<void> setAutomatic(String accountId, String labelId, {required bool automatic}) async {
    await _labels.setAutomatic(accountId, labelId, automatic: automatic);
    // ponytail: the download is not stopped when the last Etichetta automatica is turned off; #108 decides.
    if (automatic) unawaited(_model.activate());
  }
}
