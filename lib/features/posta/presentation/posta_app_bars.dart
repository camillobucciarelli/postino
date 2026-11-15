import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart' show trashLabelId;
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'refresh_mail.dart';

/// The commands of the bars of the Posta views: from `breakpoint-expanded` «Aggiorna» (#251), with its shortcut in
/// the tooltip, the phone has the pull-to-refresh; then «Cerca» (#205), the search over the view, scoped to its
/// Account.
List<PostinoMenuItem> searchCommand(BuildContext context, VoidCallback onSearch) => [
  if (MediaQuery.sizeOf(context).width >= PostinoSize.breakpointExpanded)
    PostinoMenuItem(
      key: const ValueKey('refresh'),
      label: context.t.syncStatus.refresh,
      icon: PostinoIcons.refresh,
      shortcut: defaultTargetPlatform == TargetPlatform.macOS ? '⌘R' : 'Ctrl+R',
      onPressed: () => unawaited(refreshMail(context)),
    ),
  PostinoMenuItem(label: context.t.cerca.open, icon: PostinoIcons.search, onPressed: onSearch),
];

/// “Posta unificata”, with how many Accounts it merges; [onSearch] opens the search over all of them.
class const UnifiedAppBar({super.key, required final VoidCallback onSearch}) extends StatefulWidget {
  @override
  State<UnifiedAppBar> createState() => _UnifiedAppBarState();
}

class _UnifiedAppBarState() extends State<UnifiedAppBar> with AccountsSignal {
  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => PostinoAppBar(
      commands: searchCommand(context, widget.onSearch),
      moreLabel: context.t.azioni.more,
      title: context.t.postaUnificata,
      subtitle: switch (accounts.value.value) {
        final list? => context.t.accountCount(n: list.length),
        null => null,
      },
    ),
  );
}

/// Inside one Account: its mark and name; on an Etichetta ([labelId]) the Etichetta's name over the Account's
/// ([labelName] for a folder with no Etichetta, the Bozze). [onSearch] opens the search over this Account.
class const AccountAppBar({
  super.key,
  required final String accountId,
  required final VoidCallback onSearch,
  final String? labelId,
  final String? labelName,
}) extends StatefulWidget {
  @override
  State<AccountAppBar> createState() => _AccountAppBarState();
}

class _AccountAppBarState() extends State<AccountAppBar> with AccountsSignal {
  // Every kind, as the drawer lists them: a folder of the user is named too (#311).
  late final labels = streamSignal(() => GetIt.I<InboxRepository>().watchAllLabels());

  @override
  void dispose() {
    labels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final a = accounts.value.value?.where((a) => a.id == widget.accountId).firstOrNull;
      final label = labels.value.value?[widget.accountId]?.where((l) => l.id == widget.labelId).firstOrNull;
      final name = a?.name ?? '';
      return PostinoAppBar(
        commands: searchCommand(context, widget.onSearch),
        moreLabel: context.t.azioni.more,
        title: widget.labelId == null
            ? name
            : widget.labelName ?? (widget.labelId == trashLabelId ? context.t.cestino : label?.name) ?? '',
        subtitle: widget.labelId == null ? context.t.postaInArrivo : name,
        account: a == null ? null : (color: PostinoAccountColor.values[a.color], initial: a.initial),
      );
    },
  );
}
