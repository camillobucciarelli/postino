import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/conflict.dart';
import '../domain/draft_conflict.dart';
import '../domain/error_log.dart';
import '../domain/mail_action.dart';
import '../domain/mail_sync.dart';
import '../domain/message.dart';
import '../domain/outbox_repository.dart';
import '../domain/platform_services.dart';
import '../domain/provider_search_page.dart';
import '../domain/result.dart';
import '../domain/search_query.dart';
import 'mail_store.dart';
import 'sync/account_gate.dart';
import 'sync/account_queue.dart';
import 'sync/auto_labeler.dart';
import 'sync/draft_opener.dart';
import 'sync/intent_replayer.dart';
import 'sync/new_mail_notifier.dart';
import 'sync/notification_cleanup.dart';
import 'sync/on_demand_fetcher.dart';
import 'sync/outbox_sender.dart';
import 'sync/provider_factory.dart';
import 'sync/queue_replay.dart';
import 'sync/sync_hold.dart';
import 'sync/sync_owner.dart';
import 'sync/sync_phase.dart';
import 'sync/sync_triggers.dart';

export 'sync/sync_triggers.dart' show pollEvery;

/// Sync engine (ADR 0008): initial sync once per Account, then incremental from the saved cursor
/// whenever the change signal fires, every [pollEvery], and when the network returns.
/// The one queue per Account: the replayer and the sender only ever run inside [AccountQueue].
@lazySingleton
class SyncEngine(
  final MailStore _store,
  final OutboxRepository _outboxStore,
  final Clock _clock,
  final Connectivity _connectivity,
  final BackgroundSender _background,
  final NewMailNotifier _newMail,
  final NotificationCleanup _cleanup,
  final AutoLabeler _labeler,
  final ErrorLog _log,
) implements MailSync {
  late final _gate = AccountGate(_store, _clock);
  final _queue = AccountQueue();

  /// The app's hold on the sync, against the background task's (#212).
  late final _hold = SyncHold(SyncOwner(), _queue, onAsked: syncAll, onOwned: _store.refreshAfterExternalWrites);
  late final _drafts = DraftOpener(_store, _outboxStore, removed: _gate.removed);

  /// Its Annulla invio tickers call back [flushOutbox]: the sends still go through the Account's queue.
  late final _outbox = OutboxSender(
    _outboxStore,
    _clock,
    _background,
    _log,
    account: _gate.find,
    flushOutbox: flushOutbox,
    pause: _gate.pause,
  );
  late final _replay = QueueReplay(
    IntentReplayer(_store, _outboxStore, _clock, _log, pause: _gate.pause, removed: _gate.removed),
    _outbox,
    _gate,
    _queue,
  );
  late final _fetcher = OnDemandFetcher(_store, _gate, _queue, _replay, _cleanup, _clock);
  late final _phase = SyncPhase(_store, _newMail, _cleanup, _labeler, _log, _gate, _replay, _connectivity);
  late final _triggers = SyncTriggers(
    _store,
    _clock,
    _connectivity,
    syncAll: syncAll,
    poll: _poll,
    sync: (account) => _sync(account)?.done,
    removalRunning: _gate.removalRunning,
  );

  /// Per Account, the latest Etichettatura automatica and its replay, which the sync does not wait for.
  @visibleForTesting
  Map<String, Future<void>> get autoLabeling => _phase.autoLabeling;

  /// Per Account, the ticker that sends its Bozze once the edits pause.
  final _draftTimers = <String, StreamSubscription<void>>{};

  /// The tickers that replay the «trattenute» Azioni once their Annulla window ends.
  final _holdTimers = <StreamSubscription<void>>{};

  /// Starts listening to change signals, the poll and the network, then syncs everything. Nothing goes to a Provider
  /// before the app owns the sync: a background task syncing now ends first, and later asks the app instead (#212).
  void start() {
    _hold.start();
    _triggers.start();
    unawaited(syncAll());
  }

  Future<void> stop() async {
    _hold.stop();
    await Future.wait([
      _triggers.stop(),
      for (final s in [..._draftTimers.values, ..._holdTimers]) s.cancel(),
      _outbox.stop(),
    ]);
    _draftTimers.clear();
    _holdTimers.clear();
  }

  @override
  Future<void> syncAll() async {
    _hold.ensure();
    // After the ownership: a background task syncing now has written all it will, so the streams read it (#212).
    await _hold.owned;
    // On resume the WorkManager isolate may have sent (or refused) outbox rows: the streams read the file again.
    // ponytail: only when syncAll runs (start, resume, network back); a cross-isolate notification if a worker ever writes while in foreground.
    _store.refreshAfterExternalWrites();
    await _eachActive((account) => _sync(account)?.done);
  }

  @override
  Future<void> refresh() async {
    await _hold.owned;
    _store.refreshAfterExternalWrites();
    await _eachActive((account) => _queue.running(account.id) ?? _sync(account)?.synced);
  }

  /// The background task's sync (#212), once [SyncOwner] gave it the sync: every attivo Account once, with its
  /// notifications, replay and due outbox; the Etichettatura automatica waits for the next sync in the app.
  /// With a [budget] (iOS gives about 30 s, #213) an Account whose turn comes after it ran out is not started: those
  /// that finished have their cursor saved (`applySync` is atomic), the others go on the next time.
  Future<void> syncInBackground({Duration? budget}) {
    final end = budget == null ? null : _clock.now().add(budget);
    Future<void> sync(Account a, Completer<void> s) async {
      if (end != null && !_clock.now().isBefore(end)) return;
      await _phase.run(a, s, autoLabel: false);
    }

    return _eachActive((a) => _gate.paused(a.id) ? null : _queue.sync(a.id, (s) => sync(a, s)).done);
  }

  /// Resolves once no sync is between applying a batch and its notifications (#213): short, local work, which the
  /// background task's budget does not cut off, or the mail applied would never notify.
  Future<void> commitsSettled() async {
    while (_phase.committing.isNotEmpty) {
      await Future.wait([..._phase.committing].map((c) => c.then<void>((_) {}, onError: (_) {})));
    }
  }

  Future<void> _poll() {
    _hold.ensure();
    return _eachActive((account) => _sync(account)?.done);
  }

  /// Runs [op] for every attivo Account at once: a Da ricollegare Account stops syncing until the user consents again.
  Future<void> _eachActive(Future<void>? Function(Account account) op) async {
    await Future.wait([
      for (final account in await _store.accounts())
        if (account.status == AccountStatus.attivo) op(account) ?? Future<void>.value(),
    ]);
  }

  /// Queues a sync of the Account; null while the Provider's pause holds.
  QueuedSync? _sync(Account account) =>
      _gate.paused(account.id) ? null : _queue.sync(account.id, (synced) => _phase.run(account, synced));

  @override
  Future<Result<void>> openConversation(String accountId, String conversationId) =>
      _fetcher.openConversation(accountId, conversationId);

  @override
  Future<Result<void>> completeConversation(String accountId, String conversationId) =>
      _fetcher.completeConversation(accountId, conversationId);

  @override
  Future<Result<void>> fetchBody(String accountId, String messageId) => _fetcher.fetchBody(accountId, messageId);

  @override
  Future<Result<ProviderSearchPage>> search(String accountId, SearchQuery query, {String? pageToken}) =>
      _fetcher.search(accountId, query, pageToken: pageToken);

  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String accountId,
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) => _fetcher.fetchAttachment(accountId, messageId, attachmentId, onProgress: onProgress, cancel: cancel);

  @override
  Future<void> saveDraft(String accountId, OutgoingMessage draft) async {
    // The Account removed meanwhile: nothing kept, so nothing to send later.
    if (!await _outboxStore.saveDraft(accountId, draft, updatedAt: _clock.now().millisecondsSinceEpoch)) return;
    // Swapped with no await in between: two saves in a row must not both keep a timer.
    final old = _draftTimers.remove(accountId);
    _draftTimers[accountId] = _clock.every(draftDebounce).listen((_) => unawaited(flushDrafts(accountId)));
    await old?.cancel();
  }

  /// Sends the Account's pending Bozze at once. While the Provider's pause holds they stay
  /// pending and go with the first replay after it (the next poll or sync).
  @override
  Future<void> flushDrafts(String accountId) async {
    await _draftTimers.remove(accountId)?.cancel();
    await _replay.ifActive(accountId, flush: true);
  }

  @override
  Future<Result<DateTime>> send(String accountId, OutgoingMessage message) => _outbox.send(accountId, message);

  @override
  Future<String?> cancelSend(String accountId, String messageId) => _outbox.cancelSend(accountId, messageId);

  /// Sends the Account's due outbox entries at once. While the Provider's pause holds they stay queued
  /// and go with the first replay after it (the next poll or sync); so do those of a Da ricollegare Account.
  @override
  Future<void> flushOutbox(String accountId) async {
    await _replay.ifActive(accountId, outboxOnly: true);
  }

  @override
  Future<Result<OutgoingMessage>> openDraft(String accountId, String messageId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    return _drafts.open(account, messageId, providerFor(account));
  }

  @override
  Future<Result<Label>> createLabel(String accountId, String name) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    // In the Account's queue: a sync that read the list before the creation cannot drop it afterwards.
    return _queue.run(accountId, () async {
      // Its removal started while this waited in the queue (#174): nothing is created on the Provider.
      if (_gate.removed(accountId)) return const Err(NotFoundFailure());
      final created = await providerFor(account).createLabel(name);
      if (created case Ok(:final value) when !_gate.removed(accountId)) {
        await _store.saveLabel(accountId, value);
      }
      return created;
    });
  }

  @override
  Future<void> act(
    String accountId,
    Iterable<String> messageIds,
    MailAction action, {
    Duration? hold,
    bool replay = true,
  }) async {
    // Applied here at once: a Conversazione left with nothing unread in the inbox loses its notification (#210).
    final conversations = await _cleanup.conversationsOf(accountId, messageIds);
    if (hold == null) {
      await _store.queue(accountId, messageIds, action);
      _cleanInQueue(accountId, conversations);
      // One replay for all of them: with a rate limit each would wait out the transport's backoff again.
      if (!replay) return;
      return _replay.ifActive(accountId);
    }
    await _store.queue(accountId, messageIds, action, heldUntil: _clock.now().add(hold));
    _cleanInQueue(accountId, conversations);
    late final StreamSubscription<void> timer;
    timer = _clock.every(hold).listen((_) {
      _holdTimers.remove(timer);
      unawaited(timer.cancel());
      unawaited(_replay.ifActive(accountId));
    });
    _holdTimers.add(timer);
  }

  /// In the Account's queue, after any sync running: its notifications and this cleanup never interleave.
  void _cleanInQueue(String accountId, Set<String> conversations) =>
      unawaited(_queue.run(accountId, () => _cleanup.clean(accountId, conversations)));

  @override
  Future<void> replayActions(String accountId) => _replay.ifActive(accountId, actionsOnly: true);

  @override
  Future<bool> cancelAction(String accountId, Iterable<String> messageIds, MailAction action) =>
      _store.cancelHeld(accountId, messageIds, action, _clock.now());

  @override
  Future<void> resolveConflict(Conflict conflict, {required bool keepMine}) async {
    if (await _store.resolveConflict(conflict, keepMine: keepMine) && keepMine) {
      await _replay.ifActive(conflict.accountId);
    }
  }

  @override
  Future<void> resolveDraftConflict(DraftConflict conflict, {required bool keepMine}) async {
    if (await _store.resolveDraftConflict(conflict, keepMine: keepMine) && keepMine) {
      await flushDrafts(conflict.accountId);
    }
  }

  @override
  Future<void> setLabel(String accountId, String messageId, String labelId, {required bool add}) =>
      setConversationLabel(accountId, [messageId], labelId, add: add);

  @override
  Future<void> setConversationLabel(
    String accountId,
    Iterable<String> messageIds,
    String labelId, {
    required bool add,
  }) => act(accountId, messageIds, add ? ApplyLabel(labelId) : RemoveLabel(labelId));

  /// Rimozione dell'Account (#174): stops its change signal (IDLE) and Bozze ticker, runs [delete] in its queue
  /// after whatever already runs there, then drops its adapter. A sync queued meanwhile finds no Account and stops.
  Future<void> removeAccount(String accountId, Future<void> Function() delete) async {
    _gate.removalStarted(accountId);
    _triggers.forget(accountId);
    await _draftTimers.remove(accountId)?.cancel();
    // Not behind the queue: a replay running or queued there must not send the Azioni the user gave up.
    try {
      await _store.dropQueue(accountId);
      await _queue.run(accountId, delete);
    } catch (_) {
      // Not removed after all: the Account works again (its dropped queue stays dropped).
      _gate.removalFailed(accountId);
      rethrow;
    }
    _gate.removalDone(accountId);
    // The logout of an IMAP adapter may wait on the network: the adapter is unregistered at once anyway.
    unawaited(forgetProvider(accountId));
  }
}

@module
abstract class SyncModule() {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
