import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/inbox_sections.dart';
import 'message_time.dart';

/// The tile of a Conversazione's row in a list: [entry]'s latest message, its Stella (of any message, #366), its
/// Etichette among [accountLabels], and all of it read as one button. [node] is null for a copy with no focus.
/// [showAccount] marks the row with its Account, where Accounts mix.
PostinoMessageTile conversationTile(
  BuildContext context,
  InboxEntry entry, {
  required FocusNode? node,
  required List<Label> accountLabels,
  required bool conflict,
  required bool selected,
  required bool showAccount,
  required DateTime now,
  required VoidCallback onTap,
  Map<CustomSemanticsAction, VoidCallback>? semanticActions,
}) {
  final t = context.t.list;
  final InboxEntry(message: m, account: a, :count, :unread, :status) = entry;
  final starred = isStarred(entry);
  final labels = [
    for (final l in accountLabels)
      if (l.kind == LabelKind.etichetta && m.labelIds.contains(l.id)) l.name,
  ];
  final time = messageTime(m.date, now, Localizations.localeOf(context).languageCode, t.yesterday);
  return PostinoMessageTile(
    key: ValueKey('row-${a.id}-${m.id}'),
    focusNode: node,
    customSemanticsActions: semanticActions,
    sender: m.fromName ?? m.from,
    subject: m.subject,
    preview: m.snippet,
    time: time,
    unread: unread,
    starred: starred,
    count: count,
    labels: labels,
    conflict: conflict,
    selected: selected,
    onTap: onTap,
    account: showAccount ? (color: PostinoAccountColor.values[a.color], initial: a.initial) : null,
    semanticLabel: [
      if (unread) t.unread,
      m.fromName ?? m.from,
      m.subject,
      if (count > 1) t.messages(n: count),
      if (m.snippet.isNotEmpty) m.snippet,
      ?status,
      if (conflict) context.t.conflitti.sign,
      if (starred) t.starred,
      if (showAccount) t.account(name: a.name),
      ...labels,
      time,
    ].join(', '),
  );
}
