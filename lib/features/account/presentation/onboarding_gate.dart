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

/// Shows the onboarding while there is no Account, [child] afterwards; the first Account connected asks for the
/// notifications.
class const OnboardingGate({super.key, required final Widget child}) extends StatefulWidget {
  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState() extends State<OnboardingGate> with AccountsSignal {
  /// Set while the onboarding shows: the Account connected from it asks for the notifications (#39).
  bool _onboarding = false;

  @override
  Widget build(BuildContext context) => SignalBuilder(builder: _content);

  Widget _content(BuildContext context) {
    switch (accounts.value.value) {
      case null:
        return const SizedBox.shrink();
      case []:
        _onboarding = true;
        return const _Onboarding();
      case _:
        if (_onboarding) {
          _onboarding = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(askNotificationPermission(this.context));
          });
        }
        return widget.child;
    }
  }
}

class const _Onboarding() extends StatefulWidget {
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
  );
}
