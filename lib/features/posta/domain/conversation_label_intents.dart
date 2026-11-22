import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_action.dart';
import '../../../core/domain/mail_notification.dart' show ConversationKey;
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';

/// The actions on the Etichette of a Conversazione (#107), whoever takes them (the picker, the × of a chip) and
/// whoever brings the whole Conversazione here (the opening, the picker): one per app, it outlives the widgets.
/// Per (Conversazione, Etichetta) it keeps the latest desired state while a [fetch] runs: an action goes at once to
/// the messages given, and when the fetch ends the desired state reaches the older messages it brought.
/// Offline or failed, the local ones stand.
@lazySingleton
class ConversationLabelIntents(final MailSync _sync, final InboxRepository _inbox, final Clock _clock) {
  /// Per Conversazione being fetched: the fetches running and the desired state per Etichetta (true: on).
  final _fetches = <ConversationKey, ({int running, Map<String, bool> desired})>{};

  /// The removals whose Annulla is still offered, by the token [remove] returns: the desired state before it
  /// (`before`, null: none), what it took the Etichetta off (`had`: the local messages, then the older ones the
  /// end of a fetch reached) and the view it was taken from. [forget] drops one when its Annulla goes away.
  final _removals = <Object, ({ConversationKey key, String labelId, bool? before, List<Message> had, String? view})>{};

  /// The held additions (a folder Provider) whose Annulla may still be offered: when it ends and the ids it takes
  /// back, which the end of a fetch extends with the older messages it reached.
  final _heldAdds = <(ConversationKey, String), ({DateTime until, List<String> ids})>{};

  /// How many removals still offer Annulla (for the tests: none is kept once its snackbar closes).
  int get openRemovals => _removals.length;

  /// Runs [fetch], which brings the whole Conversazione [key] here; the desired states set meanwhile reach what it
  /// brought, of what [view] shows (all with none).
  // ponytail: one desired state per Conversazione, whatever the view; key it by view too if two views fetch at once.
  Future<Result<void>> fetch(ConversationKey key, Future<Result<void>> Function() fetch, {String? view}) async {
    final desired = _fetches[key]?.desired ?? <String, bool>{};
    _fetches[key] = (running: (_fetches[key]?.running ?? 0) + 1, desired: desired);
    try {
      final r = await fetch();
      if (r is Ok<void> && desired.isNotEmpty) {
        final all = await _all(key, view);
        for (final MapEntry(key: labelId, value: add) in desired.entries) {
          // A held addition still in its window: the older messages wait with it, under its Annulla; once each,
          // as a second held voce over the first would survive that Annulla (two fetches ending together).
          final held = add ? _heldAdds[(key, labelId)] : null;
          final left = held?.until.difference(_clock.now());
          final hold = left != null && left > Duration.zero ? left : null;
          final targets = [
            for (final m in _lacking(all, labelId, add: add))
              if (hold == null || !held!.ids.contains(m.id)) m,
          ];
          if (!add) {
            for (final r in _removals.values) {
              if (r.key == key && r.labelId == labelId) r.had.addAll(targets);
            }
          }
          if (hold != null) held!.ids.addAll([for (final m in targets) m.id]);
          unawaited(_apply(key.accountId, targets, labelId, add: add, hold: hold));
        }
      }
      return r;
    } finally {
      final running = _fetches[key]!.running - 1;
      if (running == 0) {
        _fetches.remove(key);
      } else {
        _fetches[key] = (running: running, desired: desired);
      }
    }
  }

  /// Puts [labelId] on the [messages] of [key] that lack it; with [hold] (Annulla, a folder Provider) the Azione
  /// waits that long before leaving the device. Returns the messages it went on and when it is queued.
  ({List<String> ids, Future<void> queued}) add(
    ConversationKey key,
    Iterable<Message> messages,
    String labelId, {
    Duration? hold,
  }) {
    final (:targets, :queued) = _set(key, messages, labelId, add: true, hold: hold);
    final ids = [for (final m in targets) m.id];
    // ponytail: an entry stays until replaced or undone; it is dead once its window ends.
    if (hold != null) _heldAdds[(key, labelId)] = (until: _clock.now().add(hold), ids: ids);
    return (ids: ids, queued: queued);
  }

  /// Annulla of a held [add] (a folder Provider): a fetch still running no longer brings it to the older messages.
  void forgetAdd(ConversationKey key, String labelId) {
    _heldAdds.remove((key, labelId));
    final desired = _fetches[key]?.desired;
    if (desired?[labelId] == true) desired!.remove(labelId);
  }

  /// Takes [labelId] off the [messages] of [key] that have it; returns the token of its Annulla ([undoRemoval]),
  /// to [forget] when that Annulla is no longer offered. [view]: the view the [messages] are those of.
  Object remove(ConversationKey key, Iterable<Message> messages, String labelId, {String? view}) {
    final token = Object();
    final before = _fetches[key]?.desired[labelId];
    _removals[token] = (
      key: key,
      labelId: labelId,
      before: before,
      had: _set(key, messages, labelId, add: false).targets,
      view: view,
    );
    return token;
  }

  /// Annulla of the removal [token]: the desired state goes back to what it was before it. An addition puts the
  /// Etichetta on every message of the Conversazione here now; otherwise it goes back on what the removal took it
  /// off, the older messages included.
  Future<void> undoRemoval(Object token) async {
    final r = _removals.remove(token);
    if (r == null) return;
    final desired = _fetches[r.key]?.desired;
    // A later action on the Etichetta (the picker's tick) stands.
    if (desired?[r.labelId] == false) {
      if (r.before case final before?) {
        desired![r.labelId] = before;
      } else {
        desired!.remove(r.labelId);
      }
    }
    final targets = r.before == true ? _lacking(await _all(r.key, r.view), r.labelId, add: true) : r.had;
    unawaited(_apply(r.key.accountId, targets, r.labelId, add: true));
  }

  /// The Annulla of the removal [token] is gone (expired, replaced, dismissed): the removal stands, nothing kept.
  void forget(Object token) => _removals.remove(token);

  Future<List<Message>> _all(ConversationKey key, String? view) async => [
    for (final m in await _inbox.watchConversation(key.accountId, key.conversationId, view: view).first) m.message,
  ];

  ({List<Message> targets, Future<void> queued}) _set(
    ConversationKey key,
    Iterable<Message> messages,
    String labelId, {
    required bool add,
    Duration? hold,
  }) {
    _fetches[key]?.desired[labelId] = add;
    final targets = _lacking(messages, labelId, add: add);
    return (targets: targets, queued: _apply(key.accountId, targets, labelId, add: add, hold: hold));
  }

  static List<Message> _lacking(Iterable<Message> messages, String labelId, {required bool add}) =>
      messages.where((m) => m.labelIds.contains(labelId) != add).toList();

  /// Here at once, on the Provider through the offline queue (ADR 0008), with a single replay for all of them.
  Future<void> _apply(
    String accountId,
    Iterable<Message> messages,
    String labelId, {
    required bool add,
    Duration? hold,
  }) => _sync.act(
    accountId,
    [for (final m in messages) m.id],
    add ? ApplyLabel(labelId) : RemoveLabel(labelId),
    hold: hold,
  );
}
