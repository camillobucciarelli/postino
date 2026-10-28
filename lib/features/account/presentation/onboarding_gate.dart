import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/accounts_repository.dart';
import '../../../i18n/strings.g.dart';

/// Shows the onboarding while there is no Account, [child] afterwards.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final accounts = streamSignal(
    () => GetIt.I<AccountsRepository>().watchAccounts(),
  );

  @override
  void dispose() {
    accounts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => switch (accounts.value.value) {
      null => const SizedBox.shrink(),
      [] => const _Onboarding(),
      _ => widget.child,
    },
  );
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t.onboarding.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(context.t.onboarding.body),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => GetIt.I<AccountsRepository>().connectGmail(),
            child: Text(context.t.onboarding.connectGmail),
          ),
        ],
      ),
    ),
  );
}
