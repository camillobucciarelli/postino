import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/account.dart';
import '../../domain/error_log.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../../domain/sync_status.dart';
import '../mail_store.dart';
import 'account_gate.dart';
import 'auto_labeler.dart';
import 'new_mail_notifier.dart';
import 'notification_cleanup.dart';
import 'provider_factory.dart';
import 'queue_replay.dart';
import 'sync_status_board.dart';

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
  final Connectivity _connectivity,
  final SyncStatusBoard _status,
  final Clock _clock,
) {
  /// Syncs of an Account failed in a row, offline ones too, before the streak goes in the log (#252): one or two
  /// may be the network, more with the device online is a sync that never gets through.
  static const failuresToLog = SyncStatus.offlineFailuresToShow;

  /// A sync longer than this goes in the log (#322): the lines to tell a slow Provider from a stuck one.
  static const slowSyncAfter = Duration(seconds: 20);

  /// A sync still running after this goes in the log with the step it is at, its Bozze and outbox included: one
  /// that hangs ends nowhere, so nothing else would ever say it (the status only shows it running). A long first
  /// sync is logged too: the line says how long, not that it is stuck.
  static const stuckAfter = Duration(minutes: 10);

  /// The Accounts whose rate limit pause has its start in the log and not its end yet (#322).
  final _pauses = <String>{};

  /// Per Account, its syncs failed in a row and whether this streak is in the log already.
  final _streaks = <String, ({int failed, bool logged})>{};

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
    _status.started(accountId);
    var step = 'azioni in coda';
    final stuck = _clock
        .every(stuckAfter)
        .take(1)
        .listen(
          (_) => _log.record(
            'in corso da ${stuckAfter.inMinutes} min, passo: $step',
            context: 'sync ${account.provider.name}, ancora in corso',
          ),
        );
    try {
      // The Azioni first: a value changed elsewhere since they were queued is a Conflitto, not overwritten (ADR 0008).
      await _replay.beforeSync(accountId, provider);
      step = 'download';
      final paused = _gate.paused(accountId);
      if (!paused && _pauses.remove(accountId)) {
        _log.record('fine', context: 'sync ${account.provider.name}, pausa rate limit');
      }
      final started = _clock.now();
      final failure = paused
          ? null
          : await _sync(account, provider, autoLabel: autoLabel, onCommit: () => step = 'salvataggio e notifiche');
      final took = _clock.now().difference(started);
      if (took >= slowSyncAfter) _log.record('${took.inSeconds} s', context: 'sync ${account.provider.name}, lenta');
      // Before [synced]: a refresh waiting on it reads how it went.
      _status.finished(accountId, failure: failure, synced: !paused);
      synced.complete();
    } catch (e, s) {
      _status.finished(accountId, failure: UnexpectedFailure(e, s));
      synced.completeError(e, s);
      rethrow;
    } finally {
      step = 'bozze e outbox';
      // After the sync phase, failed too: a pull-to-refresh does not wait for Bozze MIME uploads nor outbox
      // attachments. Not once the sync made the Account Da ricollegare: its queue waits (ADR 0008).
      try {
        if (await _gate.active(accountId) != null) await _replay.afterSync(accountId, provider);
      } finally {
        unawaited(stuck.cancel());
      }
    }
  }

  /// Null when it went through, else why it failed.
  Future<Failure?> _sync(
    Account account,
    MailProvider provider, {
    required bool autoLabel,
    required void Function() onCommit,
  }) async {
    final accountId = account.id;
    final cursor = await _store.cursor(accountId);
    var full = cursor == null;
    // Without a cursor no initial sync ended: one that stopped midway is resumed (#394).
    final resume = full;
    Future<Result<SyncBatch>> initial({required bool resume}) {
      debugPrint('[sync] $accountId: initial sync start');
      return provider.initialSync(
        onPage: (messages, bodies) => _store.applyPage(accountId, messages, bodies),
        resume: resume,
      );
    }

    if (!full) debugPrint('[sync] $accountId: incremental sync start');
    var result = full ? await initial(resume: resume) : await provider.incrementalSync(cursor);
    if (result case Err(failure: NotFoundFailure())) {
      // Expired cursor: start over.
      full = true;
      result = await initial(resume: false);
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

        _streaks.remove(accountId);
        // Went through, but what the rate limit left out waits for the pause (#394).
        if (value.rateLimited case final limited?) {
          _pause(account, limited);
        } else {
          _gate.resetBackoff(accountId);
        }
        if (value.deferred case final deferred? when _connectivity.isOnline) {
          _log.record(
            deferred,
            context: 'sync ${account.provider.name}, ${value.deferredMessageIds.length} messaggi rimandati',
          );
        }
        onCommit();
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
        return null;
      case Err(:final failure):
        debugPrint('[sync] $accountId: failed, $failure');
        // An AuthFailure goes in the log below, by Provider: its cause never next to the address (#353).
        if (failure is! AuthFailure) _log.failure('sync $accountId', failure);
        final streak = _streaks[accountId] ?? (failed: 0, logged: false);
        final failed = streak.failed + 1;
        // An OfflineFailure alone is left out (no network is not an error); a streak of them with the network up is.
        final log = failure is OfflineFailure && !streak.logged && failed >= failuresToLog && _connectivity.isOnline;
        // The Provider, not the Account: its id is the address (#252).
        if (log) _log.record(failure, context: 'sync ${account.provider.name}, $failed di fila');
        _streaks[accountId] = (failed: failed, logged: streak.logged || log);
        if (failure is RateLimitFailure) _pause(account, failure);
        if (failure is AuthFailure) {
          // Its cause, by Provider: the Account's id holds its address (#353).
          _log.record(failure, context: 'sync ${account.provider.name}, da ricollegare');
          await _store.setStatus(accountId, AccountStatus.daRicollegare);
        }
        return failure;
    }
  }

  /// No sync of the Account until the end of [limit], or of its backoff when the Provider gives none (#394).
  void _pause(Account account, RateLimitFailure limit) {
    final until = _gate.rateLimited(account.id, limit.retryAfter);
    if (_pauses.add(account.id)) {
      _log.record('inizio, fino a $until', context: 'sync ${account.provider.name}, pausa rate limit');
    }
    debugPrint('[sync] ${account.id}: paused until $until');
  }
}
