import 'package:flutter/widgets.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/draft_conflict.dart';
import '../../../core/domain/draft_content.dart';
import '../../../core/domain/html_text.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// One Conflitto of a Bozza in the list (#149): the Account's color, then the two versions side by side, subject and
/// text, «La tua» and «Del Provider», and the two choices. Each version is a stop of its own for Tab and the screen
/// reader, with its own label. [firstChoice] is the focus of «La tua», owned by the list as in `ConflictRow`.
class const DraftConflictRow({
  super.key,
  required final DraftConflict conflict,
  required final Account account,
  required final FocusNode firstChoice,
  required final void Function({required bool keepMine}) onResolve,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t.conflitti;
    final c = context.pc;
    Widget version(String key, String heading, DraftContent v, String Function(String subject, String body) label) {
      final subject = v.subject.trim().isEmpty ? t.noSubject : v.subject;
      final body = htmlText(v.body).trim();
      return Expanded(
        child: Focus(
          key: ValueKey(key),
          child: Semantics(
            container: true,
            excludeSemantics: true,
            label: label(subject, body),
            child: PostinoFocusRing(
              child: PostinoSelectable(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: PostinoSpacing.s0_5,
                  children: [
                    Text(heading, style: PostinoText.meta.copyWith(color: c.inkMuted)),
                    Text(subject, style: PostinoText.subject.copyWith(color: c.ink)),
                    Text(body, style: PostinoText.preview.copyWith(color: c.ink)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: ValueKey('draft-conflict-${conflict.accountId}-${conflict.messageId}'),
      padding: const EdgeInsets.all(PostinoSpacing.s4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.listItemDivider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PostinoSpacing.s2,
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            label: '${t.draft}, ${t.account(name: account.name)}',
            child: Row(
              spacing: PostinoSpacing.s3,
              children: [
                PostinoAccountMark(
                  key: const ValueKey('account-mark'),
                  color: PostinoAccountColor.values[account.color],
                  initial: account.initial,
                  size: PostinoSize.accountBadge,
                ),
                Text(t.draft, style: PostinoText.sender.copyWith(color: c.ink)),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: PostinoSpacing.s4,
            children: [
              version('draft-mine', t.keepMine, conflict.mine, (s, b) => t.draftMine(subject: s, body: b)),
              version(
                'draft-provider',
                t.keepProvider,
                conflict.provider,
                (s, b) => t.draftProvider(subject: s, body: b),
              ),
            ],
          ),
          Wrap(
            spacing: PostinoSpacing.s2,
            runSpacing: PostinoSpacing.s1,
            children: [
              PostinoButton(
                key: const ValueKey('keep-mine'),
                label: t.keepMine,
                focusNode: firstChoice,
                onPressed: () => onResolve(keepMine: true),
              ),
              PostinoButton(
                key: const ValueKey('keep-provider'),
                label: t.keepProvider,
                variant: PostinoButtonVariant.ghost,
                onPressed: () => onResolve(keepMine: false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
