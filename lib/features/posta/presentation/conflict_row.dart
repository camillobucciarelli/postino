import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/conflict.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conflict_words.dart';

/// One Conflitto in the list: the Account's color, the message (sender, subject), its two versions in words and
/// the two choices, «La tua» and «Del Provider». [firstChoice] is the focus of «La tua», owned by the list so it can
/// give the focus back after a resolution; the row only calls [onResolve].
class const ConflictRow({
  super.key,
  required final Conflict conflict,
  required final Account account,
  required final FocusNode firstChoice,
  required final void Function({required bool keepMine}) onResolve,
}) extends StatefulWidget {
  @override
  State<ConflictRow> createState() => _ConflictRowState();
}

class _ConflictRowState() extends State<ConflictRow> {
  late final message = streamSignal(
    () => GetIt.I<InboxRepository>().watchMessage(widget.conflict.accountId, widget.conflict.messageId),
  );

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConflictWords(
    conflict: widget.conflict,
    builder: (context, mine, provider) => SignalBuilder(
      builder: (context) {
        final t = context.t.conflitti;
        final c = context.pc;
        final m = message.value.value;
        final a = widget.account;
        final sender = m == null ? '' : (m.fromName ?? m.from);
        final subject = m == null || m.subject.isEmpty ? t.noSubject : m.subject;
        return Container(
          key: ValueKey('conflict-${widget.conflict.accountId}-${widget.conflict.messageId}'),
          padding: const EdgeInsets.all(PostinoSpacing.s4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.listItemDivider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PostinoSpacing.s2,
            children: [
              // One node for the message and its versions; the buttons stay apart, each focusable.
              Semantics(
                container: true,
                excludeSemantics: true,
                label: [?(sender.isEmpty ? null : sender), subject, t.account(name: a.name), mine, provider].join(', '),
                child: PostinoSelectable(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PostinoSpacing.s3,
                    children: [
                      PostinoAccountMark(
                        key: const ValueKey('account-mark'),
                        color: PostinoAccountColor.values[a.color],
                        initial: a.initial,
                        size: PostinoSize.accountBadge,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: PostinoSpacing.s0_5,
                          children: [
                            if (sender.isNotEmpty) Text(sender, style: PostinoText.sender.copyWith(color: c.ink)),
                            Text(subject, style: PostinoText.subject.copyWith(color: c.ink)),
                            Text(mine, style: PostinoText.preview.copyWith(color: c.ink)),
                            Text(provider, style: PostinoText.preview.copyWith(color: c.ink)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: PostinoSpacing.s2,
                runSpacing: PostinoSpacing.s1,
                children: [
                  PostinoButton(
                    key: const ValueKey('keep-mine'),
                    label: t.keepMine,
                    focusNode: widget.firstChoice,
                    onPressed: () => widget.onResolve(keepMine: true),
                  ),
                  PostinoButton(
                    key: const ValueKey('keep-provider'),
                    label: t.keepProvider,
                    variant: PostinoButtonVariant.ghost,
                    onPressed: () => widget.onResolve(keepMine: false),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
