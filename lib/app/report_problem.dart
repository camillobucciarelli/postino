import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../features/segnalazione/domain/report_problem_use_case.dart';
import '../i18n/strings.g.dart';
import 'posta/posta_routes.dart' show openDraft;

bool _running = false;

/// Segnala un problema (#117): the Bozza to the author opens in the composer, or, without an Account, the system
/// share sheet opens on the log. Nothing is sent by itself. A report already starting ignores the call (a held key
/// repeats). A failure (log unreadable, share refused) is dropped.
// ponytail: a failure shows nothing; a Snackbar if reports ever fail in practice.
void reportProblem() {
  if (_running) return;
  _running = true;
  unawaited(_report().whenComplete(() => _running = false));
}

Future<void> _report() async {
  final s = t.segnalazione;
  try {
    final draft = await GetIt.I<ReportProblemUseCase>().start(subject: s.subject, intro: s.intro);
    if (draft != null) openDraft(draft.$1, draft.$2);
  } on Object catch (e) {
    debugPrint('[segnalazione] $e');
  }
}
