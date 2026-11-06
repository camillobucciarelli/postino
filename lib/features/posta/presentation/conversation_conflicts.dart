import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/conflict.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conflict_words.dart';

/// Above an open Conversazione: a notice for each of its messages in Conflitto, which shows its local version and
/// resolves in one tap. [messageIds] are the Conversazione's messages.
class const ConversationConflicts({super.key, required final String accountId, required final Set<String> messageIds})
    extends StatefulWidget {
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in conflicts.value.value ?? const <Conflict>[])
            if (widget.messageIds.contains(c.messageId))
              ConflictWords(
                key: ValueKey('conversation-conflict-${c.messageId}-${c.local.attribute}'),
                conflict: c,
                builder: (context, mine, provider) => PostinoBanner(
                  tone: PostinoBannerTone.warning,
                  title: t.sign,
                  message: '${t.signMessage} $mine. $provider.',
                  actionLabel: t.keepMine,
                  onAction: () => GetIt.I<MailSync>().resolveConflict(c, keepMine: true),
                  secondaryActionLabel: t.keepProvider,
                  onSecondaryAction: () => GetIt.I<MailSync>().resolveConflict(c, keepMine: false),
                ),
              ),
        ],
      );
    },
  );
}
