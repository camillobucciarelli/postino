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

  /// The older messages a late replay took an Etichetta off, for the removal's Annulla.
  // ponytail: kept until that Annulla; a few message rows per removal during a fetch, drop on the snackbar's end if it grows.
  final _removedLate = <(ConversationKey, String), List<Message>>{};

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
          if (!add) _removedLate[(key, labelId)] = [...?_removedLate[(key, labelId)], ...targets];
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

  /// Puts [labelId] on the [messages] of [key] that lack it (with [add] false, takes it off those that have it).
  void set(ConversationKey key, Iterable<Message> messages, String labelId, {required bool add}) {
    _fetches[key]?.pending[labelId] = add;
    _removedLate.remove((key, labelId));
    _apply(key.accountId, _lacking(messages, labelId, add: add), labelId, add: add);
  }

  /// Annulla of a removal of [labelId] from [had]: back on them and on the older messages a replay took it off;
  /// before the replay the removal is dropped, so it never reaches them.
  void undoRemoval(ConversationKey key, Iterable<Message> had, String labelId) {
    final pending = _fetches[key]?.pending;
    if (pending?[labelId] == false) pending!.remove(labelId);
    _apply(key.accountId, [...had, ...?_removedLate.remove((key, labelId))], labelId, add: true);
  }

  static List<Message> _lacking(Iterable<Message> messages, String labelId, {required bool add}) =>
      messages.where((m) => m.labelIds.contains(labelId) != add).toList();

  /// Here at once, on the Provider through the offline queue (#105), with a single replay for all of them.
  void _apply(String accountId, Iterable<Message> messages, String labelId, {required bool add}) =>
      unawaited(_sync.setConversationLabel(accountId, [for (final m in messages) m.id], labelId, add: add));
}
