import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// “Posta unificata”, with how many Accounts it merges.
class const UnifiedAppBar({super.key}) extends StatefulWidget {
  @override
  State<UnifiedAppBar> createState() => _UnifiedAppBarState();
}

class _UnifiedAppBarState() extends State<UnifiedAppBar> with AccountsSignal {
  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => PostinoAppBar(
      title: context.t.postaUnificata,
      subtitle: switch (accounts.value.value) {
        final list? => context.t.accountCount(n: list.length),
        null => null,
      },
    ),
  );
}

/// Inside one Account: its mark and name; on an Etichetta ([labelId]) the Etichetta's name over the Account's
/// ([labelName] for a folder with no Etichetta, the Bozze).
class const AccountAppBar({super.key, required final String accountId, final String? labelId, final String? labelName})
    extends StatefulWidget {
  @override
  State<AccountAppBar> createState() => _AccountAppBarState();
}

class _AccountAppBarState() extends State<AccountAppBar> with AccountsSignal {
  late final labels = streamSignal(() => GetIt.I<InboxRepository>().watchLabels(widget.accountId));

  @override
  void dispose() {
    labels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final a = accounts.value.value?.where((a) => a.id == widget.accountId).firstOrNull;
      final label = labels.value.value?.where((l) => l.id == widget.labelId).firstOrNull;
      final name = a?.name ?? '';
      return PostinoAppBar(
        title: widget.labelId == null ? name : widget.labelName ?? label?.name ?? '',
        subtitle: widget.labelId == null ? context.t.postaInArrivo : name,
        account: a == null ? null : (color: PostinoAccountColor.values[a.color], initial: a.initial),
      );
    },
  );
}
