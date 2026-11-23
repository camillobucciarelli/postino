import 'package:flutter/widgets.dart';

import '../../../core/domain/mail_action.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conversation_actions.dart';
import 'posta_shortcuts.dart';
import 'shortcut_labels.dart';

/// The Azioni of an open Conversazione on its bars (#369), each with its shortcut in the tooltip.
typedef ConversationBarActions = ({
  /// Archivia, or Ripristina in the Cestino.
  PostinoBarAction archive,

  /// Elimina; none in the Cestino.
  PostinoBarAction? delete,
  PostinoBarAction star,
  PostinoBarAction read,
  PostinoBarAction labels,
  PostinoBarAction forward,
  PostinoBarAction replyAll,
  PostinoBarAction reply,
});

/// The Azioni of the Conversazione: [apply] the MailActions ([starred]: it has the Stella, [read]: every message is
/// read, [view] the list it is open from), [onLabels] the picker anchored to [labelsKey], Rispondi, Rispondi a tutti,
/// Inoltra on the last message.
/// With no room they leave the bar in order Etichette, letto/non letto, Stella (then Inoltra, Rispondi a tutti);
/// Rispondi, Archivia (Ripristina) and Elimina never do.
ConversationBarActions conversationBarActions(
  BuildContext context, {
  required bool starred,
  required bool read,
  required String? view,
  required void Function(MailAction action) apply,
  required VoidCallback onLabels,
  required Key labelsKey,
  required FocusNode labelsFocus,
  required VoidCallback onReply,
  required VoidCallback onReplyAll,
  required VoidCallback onForward,
}) {
  final t = context.t.conversazione;
  String? keys(PostaAction a) => shortcutLabel(context, a);
  PostinoBarAction mail(ConversationAction a, PostaAction shortcut, {int? overflow, bool selected = false}) =>
      PostinoBarAction(
        icon: a.icon,
        label: a.label,
        onPressed: () => apply(a.action),
        shortcut: keys(shortcut),
        overflow: overflow,
        selected: selected,
      );
  final actions = conversationActions(context, starred: starred, read: read, view: view);
  final [archive, ..., star, toggleRead] = actions;
  return (
    archive: mail(archive, PostaAction.archive),
    delete: isTrash(view) ? null : mail(actions[1], PostaAction.delete),
    star: mail(star, PostaAction.star, overflow: 2, selected: starred),
    read: mail(toggleRead, read ? PostaAction.markUnread : PostaAction.markRead, overflow: 1),
    labels: PostinoBarAction(
      key: labelsKey,
      icon: PostinoIcons.tag,
      label: context.t.selettoreEtichette.button,
      onPressed: onLabels,
      focusNode: labelsFocus,
      shortcut: keys(PostaAction.labels),
      overflow: 0,
    ),
    forward: PostinoBarAction(
      key: const ValueKey('forward'),
      icon: PostinoIcons.forward,
      label: t.forward,
      onPressed: onForward,
      shortcut: keys(PostaAction.forward),
      overflow: 3,
    ),
    replyAll: PostinoBarAction(
      key: const ValueKey('reply-all'),
      icon: PostinoIcons.replyAll,
      label: t.replyAll,
      onPressed: onReplyAll,
      shortcut: keys(PostaAction.replyAll),
      overflow: 4,
    ),
    reply: PostinoBarAction(
      key: const ValueKey('reply'),
      icon: PostinoIcons.reply,
      label: t.reply,
      onPressed: onReply,
      shortcut: keys(PostaAction.reply),
      primary: true,
    ),
  );
}
