import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../design_system/design_system.dart';
import '../../i18n/strings.g.dart';
import '../domain/model_download.dart';
import 'model_download_progress.dart';

/// «Scaricare 310 MB su rete cellulare?» (#107): «Scarica ora» downloads on any network, «Aspetta il Wi-Fi»
/// (or Esc) leaves the model waiting for Wi-Fi. The focus starts on «Scarica ora».
Future<void> confirmModelDownload(BuildContext context, int sizeBytes) async {
  final model = GetIt.I<ModelDownload>();
  final t = context.t.etichetteAutomatiche.model;
  final now = await showPostinoDialog<bool>(
    context,
    title: t.confirmTitle(size: megabytes(sizeBytes)),
    cancelValue: false,
    child: Builder(
      builder: (context) => PostinoDialogActions(
        children: [
          PostinoButton(
            label: t.confirmWait,
            variant: PostinoButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PostinoButton(label: t.downloadNow, autofocus: true, onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    ),
  );
  if (now ?? false) {
    unawaited(model.download());
  } else {
    model.waitForWifi();
  }
}
