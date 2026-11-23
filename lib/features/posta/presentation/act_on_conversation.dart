import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_action.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// An «Annulla» on screen: when it ends, and whether the user took it.
class UndoOffer(final DateTime until) {
  bool taken = false;
}

/// Applies [action] to [messageIds] (a whole Conversazione) here at once. Archivia, Elimina and Ripristina are held for
/// `undoWindow` behind «Annulla» under [context]'s messenger: within it nothing leaves the device. Annulla takes back
/// the ids [messageIds] holds then, so a caller may add the ones it acts on later.
UndoOffer? actOnConversation(BuildContext context, String accountId, List<String> messageIds, MailAction action) {
  final t = context.t.azioni;
  final message = switch (action) {
    Archive() => t.archived,
    Delete() => t.deleted,
    Restore() => t.restored,
    _ => null,
  };
  final sync = GetIt.I<MailSync>();
  if (message == null) {
    unawaited(sync.act(accountId, messageIds, action));
    return null;
  }
  final queued = sync.act(accountId, messageIds, action, hold: PostinoMotion.undoWindow);
  return offerUndo(context, accountId, messageIds, action, message: message, queued: queued);
}

/// [action] on the row's Conversazione from the list (menu, swipe): through [onOpenAct] when the Conversazione is open
/// beside the list, which moves the selection on or closes it; else [actOnStoredConversation] on what [view] shows.
void actOnRow(
  BuildContext context,
  String accountId,
  String conversationId,
  MailAction action, {
  void Function(MailAction action)? onOpenAct,
  String? view,
}) {
  if (onOpenAct case final open?) return open(action);
  unawaited(actOnStoredConversation(context, accountId, conversationId, action, view: view));
}

/// The latest letto/non letto chosen per Conversazione (accountId, conversationId), by token: a non letto waiting
/// for an opening gives way to a choice made since.
// ponytail: one small entry per Conversazione ever marked, for the app's life.
final _readChoices = <(String, String), Object>{};

/// Notes a letto/non letto on the Conversazione; the token tells later whether it is still the latest.
Object chooseRead(String accountId, String conversationId) => _readChoices[(accountId, conversationId)] = Object();

/// Whether [choice] is still the latest letto/non letto on the Conversazione.
bool isLatestRead(String accountId, String conversationId, Object choice) =>
    identical(_readChoices[(accountId, conversationId)], choice);

/// [actOnConversation] from the list, where the Conversazione may never have been opened: on its messages here at
/// once, then on the older ones the sync window left out once they are fetched, unless Annulla came first; with
/// [view], only on the messages it shows.
Future<void> actOnStoredConversation(
  BuildContext context,
  String accountId,
  String conversationId,
  MailAction action, {
  String? view,
}) async {
  if (action is MarkRead || action is MarkUnread) chooseRead(accountId, conversationId);
  final ids = await idsHere(accountId, conversationId, view: view);
  if (!context.mounted) return;
  final offer = actOnConversation(context, accountId, ids, action);
  if (await GetIt.I<MailSync>().completeConversation(accountId, conversationId) is! Ok) return;
  await reachOlder(accountId, conversationId, ids, action, offer, view: view);
}

/// The ids of the messages of the Conversazione here; with [view], only those the view shows.
Future<List<String>> idsHere(String accountId, String conversationId, {String? view}) async => [
  for (final m in await GetIt.I<InboxRepository>().watchConversation(accountId, conversationId, view: view).first)
    m.message.id,
];

/// Once the whole Conversazione is here (a fetch ended): [action] on the messages [ids] lacked, unless [offer]'s
/// Annulla came first, within what is left of its window; [ids] grows with them, so that Annulla covers them too.
Future<void> reachOlder(
  String accountId,
  String conversationId,
  List<String> ids,
  MailAction action,
  UndoOffer? offer, {
  String? view,
}) async {
  final sync = GetIt.I<MailSync>();
  final older = [
    for (final id in await idsHere(accountId, conversationId, view: view))
      if (!ids.contains(id)) id,
  ];
  if (older.isEmpty || (offer?.taken ?? false)) return;
  // The rest of the same window: one Annulla for all of them.
  final left = offer?.until.difference(GetIt.I<Clock>().now());
  await sync.act(accountId, older, action, hold: left == null || left.isNegative ? null : left);
  ids.addAll(older);
  // Annulla taken while they were queued: it did not see them.
  if (offer?.taken ?? false) await sync.cancelAction(accountId, older, action);
}

/// «Annulla» under [context]'s messenger for `undoWindow`, for [action] on [messageIds] [queued] with that hold:
/// it takes the voci back ([MailSync.cancelAction]) and the Provider never hears of them; then [onUndo].
UndoOffer offerUndo(
  BuildContext context,
  String accountId,
  List<String> messageIds,
  MailAction action, {
  required String message,
  required Future<void> queued,
  VoidCallback? onUndo,
}) {
  final clock = GetIt.I<Clock>();
  final offer = UndoOffer(clock.now().add(PostinoMotion.undoWindow));
  PostinoSnackbar.show(
    context,
    message: message,
    actionLabel: context.t.azioni.undo,
    until: offer.until,
    now: clock.now,
    onAction: () {
      offer.taken = true;
      onUndo?.call();
      // After the queueing: an Annulla quicker than the database finds nothing to take back otherwise.
      unawaited(queued.then((_) => GetIt.I<MailSync>().cancelAction(accountId, messageIds, action)));
    },
  );
  return offer;
}
