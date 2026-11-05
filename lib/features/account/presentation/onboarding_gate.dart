import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/accounts_repository.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'connect_error.dart';
import 'notification_permission.dart';

/// Shows the onboarding while there is no Account (with [onReportProblem] on it), [child] afterwards, offering the notifications once per device.
class const OnboardingGate({super.key, required final Widget child, required final VoidCallback onReportProblem})
    extends StatefulWidget {
  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState() extends State<OnboardingGate> with AccountsSignal {
  /// Set once the Accounts showed up: then the notifications are offered, once per device (#39).
  bool _offered = false;

  @override
  Widget build(BuildContext context) => SignalBuilder(builder: _content);

  Widget _content(BuildContext context) {
    switch (accounts.value.value) {
      case null:
        return const SizedBox.shrink();
      case []:
        return _Onboarding(onReportProblem: widget.onReportProblem);
      case _:
        if (!_offered) {
          _offered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(askNotificationPermission(this.context));
          });
        }
        return widget.child;
    }
  }
}

class const _Onboarding({required final VoidCallback onReportProblem}) extends StatefulWidget {
  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState() extends State<_Onboarding> {
  String? error;

  Future<void> _connect() async {
    final r = await GetIt.I<AccountsRepository>().connectGmail();
    if (mounted) setState(() => error = connectError(context, r));
  }

  @override
  Widget build(BuildContext context) => PostinoOnboardingLayout(
    title: context.t.appTitle,
    message: context.t.onboarding.body,
    error: switch (error) {
      final e? => PostinoBanner(tone: PostinoBannerTone.danger, title: context.t.connect.title, message: e),
      null => null,
    },
    primaryAction: PostinoButton(
      label: context.t.onboarding.connectGmail,
      onPressed: _connect,
      size: PostinoButtonSize.lg,
    ),
    // Without an Account the Impostazioni and the drawer are out of reach: this is the way to report (#117).
    secondaryAction: PostinoButton(
      label: context.t.segnalazione.action,
      variant: PostinoButtonVariant.ghost,
      onPressed: widget.onReportProblem,
    ),
  );
}
