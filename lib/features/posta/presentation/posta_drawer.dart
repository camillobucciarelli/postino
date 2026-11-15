import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/settings_repository.dart';
import '../../../core/presentation/account_label.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// The drawer: Posta unificata, then each Account as a group that opens and closes (remembered on the device, #311),
/// holding its Posta in arrivo, Bozze, Inviata, Cestino and Etichette (the user's folders included).
/// [onOpenSettings], when given, adds the Impostazioni at the end, [onReportProblem] Segnala un problema (#117). Routing is the caller's: features don't know the routes.
class const PostaDrawer({
  super.key,
  final String? accountId,
  final String? labelId,
  required final VoidCallback onOpenUnified,
  required final void Function(String accountId) onOpenAccount,
  required final void Function(String accountId, String labelId) onOpenLabel,
  final VoidCallback? onOpenSettings,
  final VoidCallback? onReportProblem,
}) extends StatefulWidget {
  @override
  State<PostaDrawer> createState() => _PostaDrawerState();
}

class _PostaDrawerState() extends State<PostaDrawer> with AccountsSignal {
  late final unread = streamSignal(() => GetIt.I<InboxRepository>().watchUnreadFolders());
  late final labels = streamSignal(() => GetIt.I<InboxRepository>().watchAllLabels());
  late final stored = futureSignal(() => GetIt.I<SettingsRepository>().collapsedAccounts());

  /// The closed Accounts as last toggled here, ahead of the store: two quick taps both count.
  final toggled = signal<Set<String>?>(null);

  @override
  void dispose() {
    stored.dispose();
    labels.dispose();
    unread.dispose();
    super.dispose();
  }

  void _toggle(Set<String> closed, String accountId) {
    final next = closed.contains(accountId) ? ({...closed}..remove(accountId)) : {...closed, accountId};
    toggled.value = next;
    unawaited(GetIt.I<SettingsRepository>().setCollapsedAccounts(next));
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final t = context.t;
      final open = widget.accountId;
      final byAccount = labels.value.value ?? const <String, List<Label>>{};
      final folders = unread.value.value ?? const <(String, String)>{};
      String? unreadLabel({required bool any}) => any ? t.list.unread : null;
      // The Accounts are shown once their state is known, so a closed one does not close under the eyes.
      final closed = toggled.value ?? stored.value.value;
      final all = accounts.value.value ?? const <Account>[];
      return PostinoNavigationDrawer(
        sections: [
          PostinoDrawerSection(
            items: [
              PostinoDrawerItem(
                key: const ValueKey('drawer-posta-unificata'),
                label: t.postaUnificata,
                icon: PostinoIcons.inboxAll,
                active: open == null,
                unreadLabel: unreadLabel(any: folders.any((f) => f.$2 == inboxLabelId)),
                onTap: widget.onOpenUnified,
              ),
            ],
          ),
          if (closed != null)
            PostinoDrawerSection(
              title: t.account,
              items: [
                for (final a in all)
                  PostinoDrawerItem(
                    key: ValueKey('account-${a.id}'),
                    label: accountLabel(context, a, all),
                    semanticLabel: t.drawerAccount(address: accountLabel(context, a, all)),
                    account: (color: PostinoAccountColor.values[a.color], initial: a.initial),
                    reconnectLabel: a.status == AccountStatus.daRicollegare ? t.daRicollegare.status : null,
                    expanded: !closed.contains(a.id),
                    onTap: () => _toggle(closed, a.id),
                    children: [
                      PostinoDrawerItem(
                        key: ValueKey('inbox-${a.id}'),
                        label: t.postaInArrivo,
                        icon: PostinoIcons.inbox,
                        active: a.id == open && widget.labelId == null,
                        unreadLabel: unreadLabel(any: folders.contains((a.id, inboxLabelId))),
                        onTap: () => widget.onOpenAccount(a.id),
                      ),
                      // Bozze, Inviata and Cestino show no unread, as before; the Etichette do.
                      for (final (id, name, icon, counts) in [
                        (draftLabelId, t.bozze.title, PostinoIcons.pencil, false),
                        (sentLabelId, t.inviati.title, PostinoIcons.send, false),
                        // ponytail: Microsoft's Cestino is not synced (GraphFolders._unsynced): no entry until #318.
                        if (a.provider != ProviderKind.microsoft) (trashLabelId, t.cestino, PostinoIcons.trash, false),
                        for (final l in byAccount[a.id] ?? const <Label>[]) (l.id, l.name, PostinoIcons.tag, true),
                      ])
                        PostinoDrawerItem(
                          key: ValueKey('label-${a.id}-$id'),
                          label: name,
                          icon: icon,
                          active: a.id == open && widget.labelId == id,
                          unreadLabel: counts ? unreadLabel(any: folders.contains((a.id, id))) : null,
                          onTap: () => widget.onOpenLabel(a.id, id),
                        ),
                    ],
                  ),
              ],
            ),
          if (widget.onOpenSettings case final open?)
            PostinoDrawerSection(
              items: [
                PostinoDrawerItem(
                  key: const ValueKey('drawer-impostazioni'),
                  label: t.impostazioni.title,
                  icon: PostinoIcons.settings,
                  onTap: open,
                ),
                if (widget.onReportProblem case final report?)
                  PostinoDrawerItem(
                    key: const ValueKey('drawer-segnala'),
                    label: t.segnalazione.action,
                    icon: PostinoIcons.important,
                    onTap: report,
                  ),
              ],
            ),
        ],
      );
    },
  );
}
