import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_notification.dart' show ConversationKey;
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/result.dart';

/// The actions on the Etichette of a Conversazione (#107), whoever takes them (the picker, the × of a chip) and
/// whoever brings the whole Conversazione here (the opening, the picker): one per app, it outlives the widgets.
/// An action goes at once to the messages given; during a [fetch] of the same Conversazione the last action per
/// Etichetta also reaches the older messages the fetch brings, when it ends. Offline or failed, the local ones stand.
@lazySingleton
class ConversationLabelIntents(final MailSync _sync, final InboxRepository _inbox) {
  /// Per Conversazione being fetched: the fetches running and the last action per Etichetta (true: on).
  final _fetches = <ConversationKey, ({int running, Map<String, bool> pending})>{};

  /// The removals whose Annulla is still offered, by the token [remove] returns: what they took the Etichetta off,
  /// the local messages and the older ones a late replay reached. [forget] drops one when its Annulla goes away.
  final _removals = <Object, ({ConversationKey key, String labelId, List<Message> had})>{};

  /// How many removals still offer Annulla (for the tests: none is kept once its snackbar closes).
  int get openRemovals => _removals.length;

  /// Runs [fetch], which brings the whole Conversazione [key] here; the actions taken meanwhile reach what it brought.
  Future<Result<void>> fetch(ConversationKey key, Future<Result<void>> Function() fetch) async {
    final pending = _fetches[key]?.pending ?? <String, bool>{};
    _fetches[key] = (running: (_fetches[key]?.running ?? 0) + 1, pending: pending);
    try {
      final r = await fetch();
      if (r is Ok<void> && pending.isNotEmpty) {
        final all = [
          for (final m in await _inbox.watchConversation(key.accountId, key.conversationId).first) m.message,
        ];
        for (final MapEntry(key: labelId, value: add) in pending.entries) {
          final targets = _lacking(all, labelId, add: add);
          if (!add) {
            for (final r in _removals.values) {
              if (r.key == key && r.labelId == labelId) r.had.addAll(targets);
            }
          }
          _apply(key.accountId, targets, labelId, add: add);
        }
      }
      return r;
    } finally {
      final running = _fetches[key]!.running - 1;
      if (running == 0) {
        _fetches.remove(key);
      } else {
        _fetches[key] = (running: running, pending: pending);
      }
    }
  }

  /// Puts [labelId] on the [messages] of [key] that lack it.
  void add(ConversationKey key, Iterable<Message> messages, String labelId) => _set(key, messages, labelId, add: true);

  /// Takes [labelId] off the [messages] of [key] that have it; returns the token of its Annulla ([undoRemoval]),
  /// to [forget] when that Annulla is no longer offered.
  Object remove(ConversationKey key, Iterable<Message> messages, String labelId) {
    final token = Object();
    _removals[token] = (key: key, labelId: labelId, had: _set(key, messages, labelId, add: false));
    return token;
  }

  /// Annulla of the removal [token]: the Etichetta back on what it took it off, the older messages a replay
  /// reached too; before the replay the removal is dropped, so it never reaches them.
  void undoRemoval(Object token) {
    final r = _removals.remove(token);
    if (r == null) return;
    final pending = _fetches[r.key]?.pending;
    if (pending?[r.labelId] == false) pending!.remove(r.labelId);
    _apply(r.key.accountId, r.had, r.labelId, add: true);
  }

  /// The Annulla of the removal [token] is gone (expired, replaced, dismissed): the removal stands, nothing kept.
  void forget(Object token) => _removals.remove(token);

  List<Message> _set(ConversationKey key, Iterable<Message> messages, String labelId, {required bool add}) {
    _fetches[key]?.pending[labelId] = add;
    final targets = _lacking(messages, labelId, add: add);
    _apply(key.accountId, targets, labelId, add: add);
    return targets;
  }

  static List<Message> _lacking(Iterable<Message> messages, String labelId, {required bool add}) =>
      messages.where((m) => m.labelIds.contains(labelId) != add).toList();

  /// Here at once, on the Provider through the offline queue (#105), with a single replay for all of them.
  void _apply(String accountId, Iterable<Message> messages, String labelId, {required bool add}) =>
      unawaited(_sync.setConversationLabel(accountId, [for (final m in messages) m.id], labelId, add: add));
}
