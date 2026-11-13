import 'dart:ui' show FlutterView;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/mail_sync.dart';
import '../../../i18n/strings.g.dart';

/// The «Aggiorna» asked for now, which a second ask joins.
Future<void>? _running;

/// While a pull-to-refresh runs: it shows its own indicator, so the status row's icon stays still.
final pulling = signal(false);

/// An update the user asked for (#251): «Aggiorna», Cmd/Ctrl+R, the macOS menu, «Riprova», the pull-to-refresh
/// ([pull]). [MailSync.refresh] once at a time; at its end, never at its start, the screen reader hears how it went.
/// The automatic syncs never go through here, so they are never announced.
Future<void> refreshMail(BuildContext context, {bool pull = false}) {
  final run = _running ??= _refresh(
    View.of(context),
    Directionality.of(context),
    context.t,
  ).whenComplete(() => _running = null);
  if (!pull) return run;
  pulling.value = true;
  return run.whenComplete(() => pulling.value = false);
}

Future<void> _refresh(FlutterView view, TextDirection direction, Translations t) async {
  bool ok;
  try {
    ok = await GetIt.I<MailSync>().refresh();
  } on Object catch (e) {
    debugPrint('[sync] refresh: $e');
    ok = false;
  }
  await SemanticsService.sendAnnouncement(view, ok ? t.syncStatus.done : t.syncStatus.failed, direction);
}
