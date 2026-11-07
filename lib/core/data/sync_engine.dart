import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/conflict.dart';
import '../domain/draft_conflict.dart';
import '../domain/error_log.dart';
import '../domain/mail_action.dart';
import '../domain/mail_provider.dart';
import '../domain/mail_sync.dart';
import '../domain/message.dart';
import '../domain/outbox_repository.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'mail_store.dart';
import 'sync/account_gate.dart';
import 'sync/account_queue.dart';
import 'sync/auto_labeler.dart';
import 'sync/draft_opener.dart';
import 'sync/intent_replayer.dart';
import 'sync/new_mail_notifier.dart';
import 'sync/outbox_sender.dart';
import 'sync/provider_factory.dart';
import 'sync/queue_replay.dart';
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
  final AutoLabeler _labeler,
  final ErrorLog _log,
) implements MailSync {
  late final _gate = AccountGate(_store, _clock);
  final _queue = AccountQueue();
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
  late final _phase = SyncPhase(_store, _newMail, _labeler, _log, _gate, _replay);
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

  /// Starts listening to change signals, the poll and the network, then syncs everything.
  void start() {
    _triggers.start();
    unawaited(syncAll());
  }

  Future<void> stop() async {
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
    // On resume the WorkManager isolate may have sent (or refused) outbox rows: the streams read the file again.
    // ponytail: only when syncAll runs (start, resume, network back); a cross-isolate notification if a worker ever writes while in foreground.
    _store.refreshAfterExternalWrites();
    await _poll();
  }

  @override
  Future<void> refresh() async {
    _store.refreshAfterExternalWrites();
    await _eachActive((account) => _queue.running(account.id) ?? _sync(account)?.synced);
  }

  Future<void> _poll() => _eachActive((account) => _sync(account)?.done);

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
  Future<Result<void>> openConversation(String accountId, String conversationId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = providerFor(account);
    // Read here at once, offline too; the Provider hears it from the queue.
    await _store.markConversationRead(accountId, conversationId);
    // Fetched inside the Account's slot: no sync can apply a newer change between the fetch and the apply.
    // ponytail: the opening waits behind a running sync (an initial one too); a cursor check on apply if that ever hurts.
    final fetched = await _queue.run(accountId, () async {
      // Inviati and messages older than the sync window are not in the database yet.
      // ponytail: refetched on every opening (one request); remember complete Conversazioni if the quota ever matters.
      final fetched = await _fetchConversation(accountId, provider, conversationId);
      if (fetched case Ok(:final value)) {
        await _store.applyPage(accountId, value, const {});
        await _store.markConversationRead(accountId, conversationId);
      }
      // Its own replay, after any batch a sync fetched before the read: it sends every intent queued so far.
      await _replay.run(accountId, provider);
      return fetched;
    });
    return switch (fetched) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> fetchBody(String accountId, String messageId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    switch (await providerFor(account).fetchBody(messageId)) {
      case Ok(:final value):
        // Removed while the body downloaded (#174): nothing of it is written again.
        if (_gate.removed(accountId)) return const Err(NotFoundFailure());
        await _store.saveBody(accountId, messageId, value);
        return const Ok(null);
      case Err(:final failure):
        debugPrint('[sync] $accountId: body $messageId failed, $failure');
        return Err(failure);
    }
  }

  @override
  Future<void> saveDraft(String accountId, OutgoingMessage draft) async {
    await _outboxStore.saveDraft(accountId, draft, updatedAt: _clock.now().millisecondsSinceEpoch);
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
    if (await _gate.active(accountId) case final account?) {
      await _queue.run(accountId, () => _replay.run(accountId, providerFor(account), flush: true));
    }
  }

  @override
  Future<Result<DateTime>> send(String accountId, OutgoingMessage message) => _outbox.send(accountId, message);

  @override
  Future<String?> cancelSend(String accountId, String messageId) => _outbox.cancelSend(accountId, messageId);

  /// Sends the Account's due outbox entries at once. While the Provider's pause holds they stay queued
  /// and go with the first replay after it (the next poll or sync); so do those of a Da ricollegare Account.
  @override
  Future<void> flushOutbox(String accountId) async {
    if (await _gate.active(accountId) case final account?) {
      await _queue.run(accountId, () => _replay.run(accountId, providerFor(account), outboxOnly: true));
    }
  }

  @override
  Future<Result<OutgoingMessage>> openDraft(String accountId, String messageId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    return _drafts.open(account, messageId, providerFor(account));
  }

  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String accountId,
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final account = await _gate.find(accountId);
    if (account == null || _gate.removed(accountId)) return const Err(NotFoundFailure());
    final fetched = await providerFor(account)
        .fetchAttachment(messageId, attachmentId, onProgress: onProgress, cancel: cancel);
    // Removed during the download (#174): the cache does not keep it.
    return _gate.removed(accountId) ? const Err(NotFoundFailure()) : fetched;
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
  Future<void> act(String accountId, Iterable<String> messageIds, MailAction action, {Duration? hold}) async {
    if (hold == null) {
      await _store.queue(accountId, messageIds, action);
      // One replay for all of them: with a rate limit each would wait out the transport's backoff again.
      return _replay.ifActive(accountId);
    }
    await _store.queue(accountId, messageIds, action, heldUntil: _clock.now().add(hold));
    late final StreamSubscription<void> timer;
    timer = _clock.every(hold).listen((_) {
      _holdTimers.remove(timer);
      unawaited(timer.cancel());
      unawaited(_replay.ifActive(accountId));
    });
    _holdTimers.add(timer);
  }

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

  @override
  Future<Result<void>> completeConversation(String accountId, String conversationId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = providerFor(account);
    // Unlike openConversation it does not mark the Conversazione read.
    final fetched = await _queue.run(accountId, () async {
      final fetched = await _fetchConversation(accountId, provider, conversationId);
      if (fetched case Ok(:final value)) await _store.applyPage(accountId, value, const {});
      return fetched;
    });
    return switch (fetched) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

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

  /// The whole Conversazione from the Provider, unless the Account's pause holds; a rate limit pauses it.
  /// [NotFoundFailure] once the Account's removal started (#174), also when it starts during the fetch: the caller
  /// writes nothing then.
  Future<Result<List<Message>>> _fetchConversation(String id, MailProvider provider, String conversationId) async {
    if (_gate.removed(id)) return const Err(NotFoundFailure());
    if (_gate.paused(id)) return Err(RateLimitFailure(retryAfter: _gate.pausedUntil(id)));
    final fetched = await provider.fetchConversation(conversationId);
    if (_gate.removed(id)) return const Err(NotFoundFailure());
    if (fetched case Err(failure: RateLimitFailure(:final retryAfter?))) _gate.pause(id, retryAfter);
    return fetched;
  }
}

@module
abstract class SyncModule() {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
