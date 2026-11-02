import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// The drawer: Posta unificata, the Accounts (each with its Bozze under its inbox), and the Etichette of the open Account ([accountId]).
/// Routing is the caller's: features don't know the routes.
class PostaDrawer extends StatefulWidget {
  const PostaDrawer({
    super.key,
    this.accountId,
    this.labelId,
    required this.onOpenUnified,
    required this.onOpenAccount,
    required this.onOpenLabel,
    required this.onOpenDrafts,
  });

  final String? accountId;
  final String? labelId;
  final VoidCallback onOpenUnified;
  final void Function(String accountId) onOpenAccount;
  final void Function(String labelId) onOpenLabel;
  final void Function(String accountId) onOpenDrafts;

  @override
  State<PostaDrawer> createState() => _PostaDrawerState();
}

class _PostaDrawerState extends State<PostaDrawer> {
  late final accounts = streamSignal(
    () => GetIt.I<AccountsRepository>().watchAccounts(),
  );
  // The docked drawer outlives navigation: the open Account is a signal, the Etichette follow it.
  late final openAccount = signal(widget.accountId);
  late final unread = streamSignal(
    () => GetIt.I<InboxRepository>().watchUnreadFolders(),
  );
  late final labels = streamSignal(
    () => switch (openAccount.value) {
      final id? => GetIt.I<InboxRepository>().watchLabels(id),
      null => Stream.value(const <Label>[]),
    },
  );

  @override
  void didUpdateWidget(PostaDrawer old) {
    super.didUpdateWidget(old);
    openAccount.value = widget.accountId;
  }

  @override
  void dispose() {
    accounts.dispose();
    labels.dispose();
    unread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final t = context.t;
      final open = widget.accountId;
      final etichette = labels.value.value ?? const <Label>[];
      final folders = unread.value.value ?? const <(String, String)>{};
      String? unreadLabel(bool any) => any ? t.list.unread : null;
      return PostinoNavigationDrawer(
        sections: [
          PostinoDrawerSection(
            items: [
              PostinoDrawerItem(
                key: const ValueKey('drawer-posta-unificata'),
                label: t.postaUnificata,
                icon: PostinoIcons.inboxAll,
                active: open == null,
                unreadLabel: unreadLabel(
                  folders.any((f) => f.$2 == inboxLabelId),
                ),
                onTap: widget.onOpenUnified,
              ),
            ],
          ),
          PostinoDrawerSection(
            title: t.account,
            items: [
              for (final a in accounts.value.value ?? const <Account>[]) ...[
                PostinoDrawerItem(
                  key: ValueKey('account-${a.id}'),
                  label: a.name,
                  account: (
                    color: PostinoAccountColor.values[a.color],
                    initial: a.initial,
                  ),
                  active: a.id == open && widget.labelId == null,
                  unreadLabel: unreadLabel(
                    folders.contains((a.id, inboxLabelId)),
                  ),
                  reconnectLabel: a.status == AccountStatus.daRicollegare
                      ? t.daRicollegare.status
                      : null,
                  onTap: () => widget.onOpenAccount(a.id),
                ),
                PostinoDrawerItem(
                  key: ValueKey('drafts-${a.id}'),
                  label: t.bozze.title,
                  icon: PostinoIcons.pencil,
                  active: a.id == open && widget.labelId == draftLabelId,
                  onTap: () => widget.onOpenDrafts(a.id),
                ),
              ],
            ],
          ),
          if (etichette.isNotEmpty)
            PostinoDrawerSection(
              title: t.etichette,
              items: [
                for (final l in etichette)
                  PostinoDrawerItem(
                    key: ValueKey('label-${l.id}'),
                    label: l.name,
                    icon: PostinoIcons.tag,
                    active: l.id == widget.labelId,
                    unreadLabel: unreadLabel(folders.contains((open!, l.id))),
                    onTap: () => widget.onOpenLabel(l.id),
                  ),
              ],
            ),
        ],
      );
    },
  );
}
