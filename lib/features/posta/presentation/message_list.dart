import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'message_time.dart';

/// List of messages (Posta unificata, an Account's inbox, an Etichetta); reads only from the local database through [InboxRepository].
/// Pull-to-refresh asks for a sync; the rows update when it writes the database.
class MessageList extends StatefulWidget {
  const MessageList({super.key, required this.watch, this.showAccount = false});

  /// Which messages to show, e.g. `repo.watchUnifiedInbox`.
  final Stream<List<InboxEntry>> Function(InboxRepository repo) watch;

  /// Marks each row with its Account (bar and badge): only where Accounts mix.
  final bool showAccount;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  late final entries = streamSignal(
    () => widget.watch(GetIt.I<InboxRepository>()),
  );

  @override
  void dispose() {
    entries.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final list = entries.value.value;
      final t = context.t.list;
      final now = GetIt.I<Clock>().now();
      final locale = Localizations.localeOf(context).languageCode;
      return PostinoMessageList(
        loading: list == null,
        itemCount: list?.length ?? 0,
        onRefresh: GetIt.I<MailSync>().syncAll,
        loadingLabel: t.loading,
        emptyTitle: t.emptyTitle,
        emptyBody: t.emptyBody,
        itemBuilder: (context, i) {
          final InboxEntry(message: m, account: a) = list![i];
          final time = messageTime(m.date, now, locale, t.yesterday);
          return PostinoMessageTile(
            key: ValueKey('row-${a.id}-${m.id}'),
            sender: m.from,
            subject: m.subject,
            preview: m.snippet,
            time: time,
            unread: !m.isRead,
            starred: m.isStarred,
            account: widget.showAccount
                ? (
                    color: PostinoAccountColor.values[a.color],
                    initial: a.initial,
                  )
                : null,
            semanticLabel: [
              if (!m.isRead) t.unread,
              m.from,
              m.subject,
              if (m.isStarred) t.starred,
              if (widget.showAccount) t.account(name: a.name),
              time,
            ].join(', '),
          );
        },
      );
    },
  );
}
