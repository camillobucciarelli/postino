import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/error_log.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// After a run that ended with an uncaught error (the crash mark of #116, consumed here, so once) offers the
/// Segnalazione di un problema in a Dialog; declining it does not offer it again. Mounted once above the Posta
/// views. Routing is the caller's: [onReport] starts the report.
class const CrashReportPrompt({super.key, required final VoidCallback onReport, required final Widget child})
    extends StatefulWidget {
  @override
  State<CrashReportPrompt> createState() => _CrashReportPromptState();
}

class _CrashReportPromptState() extends State<CrashReportPrompt> {
  @override
  void initState() {
    super.initState();
    // The Dialog needs the first frame (and the Navigator) to be there.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_offer()));
  }

  Future<void> _offer() async {
    final crashed = await GetIt.I<ErrorLog>().takeCrashMark();
    if (!crashed || !mounted) return;
    final t = context.t.segnalazione;
    final accepted = await showPostinoConfirmDialog(
      context,
      title: t.crashTitle,
      message: t.crashBody,
      confirmLabel: t.crashConfirm,
      cancelLabel: t.crashDismiss,
    );
    if (accepted && mounted) widget.onReport();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
