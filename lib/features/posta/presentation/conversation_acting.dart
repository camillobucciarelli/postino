import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/inbox_repository.dart' show ConversationMessage;
import '../../../core/domain/mail_action.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../design_system/design_system.dart';
import 'act_on_conversation.dart';
import 'conversation_actions.dart';
import 'conversation_view.dart';
import 'posta_shortcuts.dart';

/// The Azioni of an open Conversazione (#146): its header buttons, the shortcuts and the row menu of its row, on
/// every message. Archivia and Elimina take it out of the list: the next one opens (or it closes); non letto
/// closes it, or the opening would read it again. They reach the messages its view shows only, as the opening.
mixin ConversationActing on State<ConversationView> {
  /// The messages shown, null until the database answers.
  List<ConversationMessage>? get shownMessages;

  /// The opening running (or done): it reads what it fetches, so non letto waits for it.
  Future<void> get opening;

  /// Set once the Conversazione closes on non letto: the messages turning unread must not read it again.
  bool closing = false;

  bool get _starred => shownMessages?.any((m) => m.message.isStarred) ?? false;

  @override
  void initState() {
    super.initState();
    widget.cursor
      ?..act = _onShortcut
      ..apply = applyAction;
  }

  @override
  void dispose() {
    final cursor = widget.cursor;
    if (cursor?.act == _onShortcut) cursor!.act = null;
    if (cursor?.apply == applyAction) cursor!.apply = null;
    super.dispose();
  }

  void _onShortcut(PostaAction shortcut) {
    if (mailActionFor(shortcut, starred: _starred) case final action?) applyAction(action);
  }

  /// Applies [action] to the whole Conversazione, then moves on or closes.
  void applyAction(MailAction action) {
    final messages = shownMessages;
    if (messages == null || messages.isEmpty) return;
    final ids = [for (final m in messages) m.message.id];
    final (accountId, conversationId) = (widget.accountId, widget.conversationId);
    if (action is MarkUnread) {
      final sync = GetIt.I<MailSync>();
      final choice = chooseRead(accountId, conversationId);
      unawaited(sync.act(accountId, ids, action));
      // The opening reads what it fetches: after it, non letto again on all of them, unless letto came since.
      unawaited(
        opening.then((_) async {
          if (!isLatestRead(accountId, conversationId, choice)) return;
          await sync.act(accountId, await idsHere(accountId, conversationId, view: widget.view), action);
        }),
      );
    } else {
      if (action is MarkRead) chooseRead(accountId, conversationId);
      final offer = actOnConversation(context, accountId, ids, action);
      // An opening still running brings older messages: they get it too, under the same Annulla.
      unawaited(opening.then((_) => reachOlder(accountId, conversationId, ids, action, offer, view: widget.view)));
    }
    final leaving = leavesList(action);
    if (leaving && (widget.cursor?.leave?.call((widget.accountId, widget.conversationId)) ?? false)) return;
    if (leaving || action is MarkUnread) {
      closing = true;
      widget.onBack();
    }
  }

  /// The Azioni as commands of the header: icon buttons while they fit, the rest in its «more» menu.
  List<PostinoMenuItem> actionCommands(BuildContext context) => [
    for (final a in conversationActions(
      context,
      starred: _starred,
      read: shownMessages?.every((m) => m.message.isRead) ?? true,
    ))
      PostinoMenuItem(icon: a.icon, label: a.label, onPressed: () => applyAction(a.action)),
  ];
}
