import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/conflict.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conflict_words.dart';
import 'message_time.dart';

/// Above an open Conversazione: a notice for each of its messages in Conflitto, which shows its local version and
/// resolves in one tap; it names the message by sender and date. [messages] are the Conversazione's, by id.
class const ConversationConflicts({
  super.key,
  required final String accountId,
  required final Map<String, Message> messages,
}) extends StatefulWidget {
  @override
  State<ConversationConflicts> createState() => _ConversationConflictsState();
}

class _ConversationConflictsState() extends State<ConversationConflicts> {
  late final conflicts = streamSignal(() => GetIt.I<InboxRepository>().watchConflicts(accountId: widget.accountId));

  @override
  void dispose() {
    conflicts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final t = context.t.conflitti;
      final now = GetIt.I<Clock>().now();
      final locale = Localizations.localeOf(context).languageCode;
      final mine = [
        for (final c in conflicts.value.value ?? const <Conflict>[])
          if (widget.messages.containsKey(c.messageId)) c,
      ];
      if (mine.isEmpty) return const SizedBox.shrink();
      // Bounded and scrollable: several notices at large text must not squeeze the thread out.
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .4),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in mine)
                ConflictWords(
                  key: ValueKey('conversation-conflict-${c.messageId}-${c.local.attribute}'),
                  conflict: c,
                  builder: (context, local, provider) => PostinoBanner(
                    tone: PostinoBannerTone.warning,
                    title: t.signFor(
                      sender: widget.messages[c.messageId]!.fromName ?? widget.messages[c.messageId]!.from,
                      time: messageTime(widget.messages[c.messageId]!.date, now, locale, context.t.list.yesterday),
                    ),
                    message: '${t.signMessage} $local. $provider.',
                    actionLabel: t.keepMine,
                    onAction: () => GetIt.I<MailSync>().resolveConflict(c, keepMine: true),
                    secondaryActionLabel: t.keepProvider,
                    onSecondaryAction: () => GetIt.I<MailSync>().resolveConflict(c, keepMine: false),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
