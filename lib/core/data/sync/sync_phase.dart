import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/account.dart';
import '../../domain/error_log.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';
import '../mail_store.dart';
import 'account_gate.dart';
import 'auto_labeler.dart';
import 'new_mail_notifier.dart';
import 'notification_cleanup.dart';
import 'provider_factory.dart';
import 'queue_replay.dart';

/// One sync of an Account (ADR 0008): the Azioni, the initial sync or the incremental one from the saved cursor,
/// then the Bozze and the outbox. An expired cursor starts over; an auth failure makes the Account Da ricollegare.
/// Runs only inside the Account's serial queue.
class SyncPhase(
  final MailStore _store,
  final NewMailNotifier _newMail,
  final NotificationCleanup _cleanup,
  final AutoLabeler _labeler,
  final ErrorLog _log,
  final AccountGate _gate,
  final QueueReplay _replay,
) {
  /// Per Account, the latest Etichettatura automatica and its replay, which the sync does not wait for.
  final autoLabeling = <String, Future<void>>{};

  /// The syncs between the apply of a batch and the end of its notifications: the background task's budget (#213)
  /// waits for them, as the engine is destroyed once it returns and the mail applied would never notify.
  final committing = <Future<void>>{};

  /// The Azioni, the sync, then the Bozze and the outbox; [synced] completes before these last two. Without
  /// [autoLabel] (the background task, #212) the new mail is left to the next sync's Etichettatura automatica.
  Future<void> run(Account account, Completer<void> synced, {bool autoLabel = true}) async {
    final accountId = account.id;
    // Removed while this sync waited in the queue (#174): nothing of it is written again, and its adapter, already
    // dropped, is not created again.
    if (await _gate.find(accountId) == null) return;
    final provider = providerFor(account);
    try {
      // The Azioni first: a value changed elsewhere since they were queued is a Conflitto, not overwritten (ADR 0008).
      await _replay.beforeSync(accountId, provider);
      if (!_gate.paused(accountId)) await _sync(account, provider, autoLabel: autoLabel);
      synced.complete();
    } catch (e, s) {
      synced.completeError(e, s);
      rethrow;
    } finally {
      // After the sync phase, failed too: a pull-to-refresh does not wait for Bozze MIME uploads nor outbox
      // attachments. Not once the sync made the Account Da ricollegare: its queue waits (ADR 0008).
      if (await _gate.active(accountId) != null) await _replay.afterSync(accountId, provider);
    }
  }

  Future<void> _sync(Account account, MailProvider provider, {required bool autoLabel}) async {
    final accountId = account.id;
    final cursor = await _store.cursor(accountId);
    var full = cursor == null;
    Future<Result<SyncBatch>> initial() {
      debugPrint('[sync] $accountId: initial sync start');
      return provider.initialSync(onPage: (messages, bodies) => _store.applyPage(accountId, messages, bodies));
    }

    if (!full) debugPrint('[sync] $accountId: incremental sync start');
    var result = full ? await initial() : await provider.incrementalSync(cursor);
    if (result case Err(failure: NotFoundFailure())) {
      // Expired cursor: start over.
      full = true;
      result = await initial();
    }
    switch (result) {
      case Ok(:final value):
        // Before the apply, which makes every message known; the initial sync notifies nothing (#39).
        // ponytail: a sync redone for an expired cursor notifies nothing either; diff against the database if that loses mail.
        final unknown = full ? const <Message>[] : await _store.unknown(accountId, value.messages);
        final fresh = await _newMail.fresh(accountId, unknown);
        // The messages the batch touched, the removed ones too (#238).
        // ponytail: a sync redone from scratch cleans nothing; the next incremental one catches up.
        final touched = full ? const <String>{} : {for (final m in value.messages) m.id, ...value.removedMessageIds};
        // The cursor is saved here, from the complete batch: pages alone never save it.
        Future<void> commit() async {
          // Removed meanwhile (from another device too, ADR 0016): no notification for mail that is not here.
          if (!await _store.applySync(accountId, value, fullSnapshot: full)) return;
          await _newMail.notify(account, fresh);
          await _cleanup.clean(accountId, touched);
          // Not awaited: its replay goes through the Account's queue, which this sync holds until it ends.
          if (!autoLabel) {
            await _labeler.defer(accountId, unknown);
          } else if (unknown.isNotEmpty || await _labeler.hasDeferred(accountId)) {
            final run = _labeler.queueAutoLabels(accountId, unknown, value.bodies);
            unawaited(autoLabeling[accountId] = run.then((queued) => queued ? _replay.ifActive(accountId) : null));
          }
        }

        final committed = commit();
        committing.add(committed);
        try {
          await committed;
        } finally {
          committing.remove(committed);
        }
        debugPrint(
          '[sync] $accountId: ${full ? 'initial' : 'incremental'} sync end, '
          '${value.messages.length} messages, ${value.removedMessageIds.length} removed',
        );
      case Err(:final failure):
        debugPrint('[sync] $accountId: failed, $failure');
        _log.failure('sync $accountId', failure);
        if (failure case RateLimitFailure(:final retryAfter?)) {
          _gate.pause(accountId, retryAfter);
          debugPrint('[sync] $accountId: paused until $retryAfter');
        }
        // ponytail: a fixed retry on the next poll; exponential backoff if Providers keep refusing.
        if (failure is AuthFailure) {
          await _store.setStatus(accountId, AccountStatus.daRicollegare);
        }
    }
  }
}
