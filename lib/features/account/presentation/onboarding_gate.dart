import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'account_choices.dart';
import 'notification_permission.dart';

/// Shows the onboarding while there is no Account (with [onReportProblem] on it), [child] afterwards, offering the notifications once per device.
/// The onboarding fades through to [child] when the first Account arrives, and back when the last one goes (#283);
/// what the start shows is just there.
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
    final all = accounts.value.value;
    if (all == null) return const SizedBox.shrink();
    if (all.isNotEmpty && !_offered) {
      _offered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(askNotificationPermission(this.context));
      });
    }
    return PostinoFadeThrough(
      transitionKey: all.isEmpty,
      child: all.isEmpty ? _Onboarding(onReportProblem: widget.onReportProblem) : widget.child,
    );
  }
}

class const _Onboarding({required final VoidCallback onReportProblem}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PostinoOnboardingLayout(
    title: context.t.appTitle,
    message: context.t.onboarding.body,
    // Once the Account exists the gate shows the Posta: nothing to do on connection.
    primaryAction: const AccountChoices(),
    // Without an Account the Impostazioni and the drawer are out of reach: this is the way to report (#117).
    secondaryAction: PostinoButton(
      label: context.t.segnalazione.action,
      variant: PostinoButtonVariant.ghost,
      onPressed: onReportProblem,
    ),
  );
}
