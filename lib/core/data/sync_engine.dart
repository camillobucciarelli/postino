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
import 'sync/auto_labeler.dart';
import 'sync/draft_opener.dart';
import 'sync/intent_replayer.dart';
import 'sync/new_mail_notifier.dart';
import 'sync/outbox_sender.dart';
import 'sync/provider_factory.dart';

/// Polling period: the change signal watches only the inbox, so the poll also brings Bozze and the rest (ADR 0008).
const pollEvery = Duration(seconds: 60);

/// Sync engine (ADR 0008): initial sync once per Account, then incremental from the saved cursor
/// whenever the change signal fires, every [pollEvery], and when the network returns.
/// The one queue per Account: the replayer and the sender only ever run inside [_serial].
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
  late final _intents = IntentReplayer(
    _store,
    _outboxStore,
    _clock,
    _log,
    pause: _pauseAccount,
    removed: _removing.containsKey,
  );

  /// Accounts whose removal started (#174), true once their data is deleted: their queue sends nothing more, and
  /// what was downloading for them is not written (set before the delete, so a check right before a write is
  /// enough). The entry goes when the same Account is connected again.
  final _removing = <String, bool>{};
  late final _drafts = DraftOpener(_store, _outboxStore, removed: _removing.containsKey);

  /// Its Annulla invio tickers call back [flushOutbox]: the sends still go through [_serial].
  late final _outbox = OutboxSender(
    _outboxStore,
    _clock,
    _background,
    _log,
    account: _account,
    flushOutbox: flushOutbox,
    pause: _pauseAccount,
  );

  void _pauseAccount(String id, DateTime until) => _pausedUntil[id] = until;

  final _subs = <StreamSubscription<Object?>>[];
  final _signals = <String, StreamSubscription<ChangeSignal>>{};

  /// Accounts the Provider blocked until a given time: no sync before it.
  final _pausedUntil = <String, DateTime>{};

  /// Per Account, the tail of its serial queue: syncs, Conversazione hydrations and replays
  /// run one after the other, so none applies a Provider answer older than one already applied.
  final _tail = <String, Future<void>>{};

  /// Per Account, the sync waiting in the queue: more requests join it instead of piling up.
  /// `synced` completes at the end of its sync phase, before the Bozze and outbox go.
  final _queuedSync = <String, _QueuedSync>{};

  /// Per Account, the sync phase of the sync running now (finished once it reaches the Bozze and the outbox):
  /// a pull-to-refresh waits for it instead of queuing another.
  final _runningSync = <String, Future<void>>{};

  /// Per Account, the latest Etichettatura automatica and its replay, which the sync does not wait for.
  @visibleForTesting
  final autoLabeling = <String, Future<void>>{};

  /// Per Account, the ticker that sends its Bozze once the edits pause.
  final _draftTimers = <String, StreamSubscription<void>>{};

  /// The tickers that replay the «trattenute» Azioni once their Annulla window ends.
  final _holdTimers = <StreamSubscription<void>>{};

  /// Starts listening to change signals, the poll and the network, then syncs everything.
  void start() {
    _subs
      ..add(_store.watchAccounts().listen(_watchSignals))
      ..add(_clock.every(pollEvery).listen((_) => _poll()))
      ..add(
        _connectivity.onChanged.listen((online) {
          if (online) unawaited(syncAll());
        }),
      );
    unawaited(syncAll());
  }

  Future<void> stop() async {
    await Future.wait([
      for (final s in [..._subs, ..._signals.values, ..._draftTimers.values, ..._holdTimers]) s.cancel(),
      _outbox.stop(),
    ]);
    _subs.clear();
    _signals.clear();
    _draftTimers.clear();
    _holdTimers.clear();
  }

  @override
  Future<void> syncAll() async {
    // On resume the WorkManager isolate may have sent (or refused) outbox rows: the streams read the file again.
    // ponytail: only when syncAll runs (start, resume, network back); a cross-isolate notification if a worker ever writes while in foreground.
    _store.refreshAfterExternalWrites();
    await Future.wait([
      for (final account in await _store.accounts())
        // A Da ricollegare Account stops syncing until the user consents again.
        if (account.status == AccountStatus.attivo) _sync(account)?.done ?? Future<void>.value(),
    ]);
  }

  @override
  Future<void> refresh() async {
    _store.refreshAfterExternalWrites();
    await Future.wait([
      for (final account in await _store.accounts())
        if (account.status == AccountStatus.attivo)
          _runningSync[account.id] ?? _sync(account)?.synced ?? Future<void>.value(),
    ]);
  }

  @override
  Future<Result<void>> openConversation(String accountId, String conversationId) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = providerFor(account);
    // Read here at once, offline too; the Provider hears it from the queue.
    await _store.markConversationRead(accountId, conversationId);
    // Fetched inside the Account's slot: no sync can apply a newer change between the fetch and the apply.
    // ponytail: the opening waits behind a running sync (an initial one too); a cursor check on apply if that ever hurts.
    final fetched = await _serial(accountId, () async {
      // Inviati and messages older than the sync window are not in the database yet.
      // ponytail: refetched on every opening (one request); remember complete Conversazioni if the quota ever matters.
      final fetched = await _fetchConversation(accountId, provider, conversationId);
      if (fetched case Ok(:final value)) {
        await _store.applyPage(accountId, value, const {});
        await _store.markConversationRead(accountId, conversationId);
      }
      // Its own replay, after any batch a sync fetched before the read: it sends every intent queued so far.
      await _replay(accountId, provider);
      return fetched;
    });
    return switch (fetched) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> fetchBody(String accountId, String messageId) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    switch (await providerFor(account).fetchBody(messageId)) {
      case Ok(:final value):
        // Removed while the body downloaded (#174): nothing of it is written again.
        if (_removing.containsKey(accountId)) return const Err(NotFoundFailure());
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
    if (await _activeAccount(accountId) case final account?) {
      await _serial(accountId, () => _replay(accountId, providerFor(account), flush: true));
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
    if (await _activeAccount(accountId) case final account?) {
      await _serial(accountId, () => _replay(accountId, providerFor(account), outboxOnly: true));
    }
  }

  @override
  Future<Result<OutgoingMessage>> openDraft(String accountId, String messageId) async {
    final account = await _account(accountId);
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
    final account = await _account(accountId);
    if (account == null || _removing.containsKey(accountId)) return const Err(NotFoundFailure());
    final fetched = await providerFor(account)
        .fetchAttachment(messageId, attachmentId, onProgress: onProgress, cancel: cancel);
    // Removed during the download (#174): the cache does not keep it.
    return _removing.containsKey(accountId) ? const Err(NotFoundFailure()) : fetched;
  }

  @override
  Future<Result<Label>> createLabel(String accountId, String name) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    // In the Account's queue: a sync that read the list before the creation cannot drop it afterwards.
    return _serial(accountId, () async {
      // Its removal started while this waited in the queue (#174): nothing is created on the Provider.
      if (_removing.containsKey(accountId)) return const Err(NotFoundFailure());
      final created = await providerFor(account).createLabel(name);
      if (created case Ok(:final value) when !_removing.containsKey(accountId)) {
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
      return _replayIfActive(accountId);
    }
    await _store.queue(accountId, messageIds, action, heldUntil: _clock.now().add(hold));
    late final StreamSubscription<void> timer;
    timer = _clock.every(hold).listen((_) {
      _holdTimers.remove(timer);
      unawaited(timer.cancel());
      unawaited(_replayIfActive(accountId));
    });
    _holdTimers.add(timer);
  }

  @override
  Future<bool> cancelAction(String accountId, Iterable<String> messageIds, MailAction action) =>
      _store.cancelHeld(accountId, messageIds, action, _clock.now());

  @override
  Future<void> resolveConflict(Conflict conflict, {required bool keepMine}) async {
    if (await _store.resolveConflict(conflict, keepMine: keepMine) && keepMine) {
      await _replayIfActive(conflict.accountId);
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
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = providerFor(account);
    // Unlike openConversation it does not mark the Conversazione read.
    final fetched = await _serial(accountId, () async {
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
    _removing[accountId] = false;
    // Not awaited, as in _watchSignals: ending IDLE may wait on the network.
    unawaited(_signals.remove(accountId)?.cancel());
    await _draftTimers.remove(accountId)?.cancel();
    // Not behind the queue: a replay running or queued there must not send the Azioni the user gave up.
    try {
      await _store.dropQueue(accountId);
      await _serial(accountId, delete);
    } catch (_) {
      // Not removed after all: the Account works again (its dropped queue stays dropped).
      _removing.remove(accountId);
      rethrow;
    }
    _removing[accountId] = true;
    _pausedUntil.remove(accountId);
    // The logout of an IMAP adapter may wait on the network: the adapter is unregistered at once anyway.
    unawaited(forgetProvider(accountId));
  }

  Future<Account?> _account(String id) async => (await _store.accounts()).where((a) => a.id == id).firstOrNull;

  /// The Account if its queue may go to the Provider now: not paused, not Da ricollegare (it waits for the reconnection).
  /// Never once its removal started (#174).
  Future<Account?> _activeAccount(String id) async {
    if (_paused(id) || _removing.containsKey(id)) return null;
    final account = await _account(id);
    return account?.status == AccountStatus.attivo ? account : null;
  }

  /// Runs [op] after everything already queued for the Account; a failure does not block the queue.
  Future<T> _serial<T>(String accountId, Future<T> Function() op) {
    final run = (_tail[accountId] ?? Future<void>.value()).then((_) => op());
    _tail[accountId] = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Sends the offline queue (ADR 0008): the intents and Bozze, then the due outbox entries.
  /// With [outboxOnly] only the outbox goes (the 10 s timer and the WorkManager isolate): Bozze uploads
  /// have no cross-isolate claim, so they stay with their own timers and the sync's replay.
  /// Called only from inside the Account's serial queue.
  Future<void> _replay(String accountId, MailProvider provider, {bool flush = false, bool outboxOnly = false}) async {
    // Its removal started (#174): nothing more goes to the Provider.
    if (_removing.containsKey(accountId)) return;
    // A send ahead of this one in the queue may have just paused the Account.
    if (_paused(accountId)) return;
    if (!outboxOnly) await _intents.replay(accountId, provider, flush: flush);
    // The replay may have just paused it (a rate-limited Etichetta): no send before the deadline.
    if (_paused(accountId)) return;
    await _outbox.sendDue(accountId, provider);
  }

  Future<void> _poll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        if (account.status == AccountStatus.attivo) _sync(account)?.done ?? Future<void>.value(),
    ]);
  }

  /// One change-signal subscription per attivo Account.
  void _watchSignals(List<Account> accounts) {
    final attivi = {
      for (final a in accounts)
        if (a.status == AccountStatus.attivo) a.id: a,
    };
    for (final id in _signals.keys.toList()) {
      if (!attivi.containsKey(id)) {
        unawaited(_signals.remove(id)!.cancel());
      }
    }
    for (final a in attivi.values) {
      // Still listed while its removal runs; listed again after it: connected anew.
      if (_removing[a.id] == false) continue;
      _removing.remove(a.id);
      if (_signals.containsKey(a.id)) continue;
      _signals[a.id] = providerFor(a).changes.listen((signal) {
        switch (signal) {
          // Up: whatever changed while it was down.
          case ChangeSignal.up || ChangeSignal.changed:
            unawaited(_sync(a)?.done);
          case ChangeSignal.down:
        }
      });
    }
  }

  /// Queues a sync of the Account; requests made before it starts share it, a request while it runs queues another.
  /// Null while the Provider's pause holds.
  _QueuedSync? _sync(Account account) {
    final id = account.id;
    if (_paused(id)) return null;
    if (_queuedSync[id] case final queued?) return queued;
    final synced = Completer<void>();
    // A failure reaches the callers through `done` too: with no pull listening it is not reported twice.
    synced.future.ignore();
    final done = _serial(id, () {
      _queuedSync.remove(id);
      _runningSync[id] = synced.future;
      return _syncOnce(account, synced);
    });
    return _queuedSync[id] = (done: done, synced: synced.future);
  }

  /// The whole Conversazione from the Provider, unless the Account's pause holds; a rate limit pauses it.
  /// [NotFoundFailure] once the Account's removal started (#174), also when it starts during the fetch: the caller
  /// writes nothing then.
  Future<Result<List<Message>>> _fetchConversation(String id, MailProvider provider, String conversationId) async {
    if (_removing.containsKey(id)) return const Err(NotFoundFailure());
    if (_paused(id)) return Err(RateLimitFailure(retryAfter: _pausedUntil[id]));
    final fetched = await provider.fetchConversation(conversationId);
    if (_removing.containsKey(id)) return const Err(NotFoundFailure());
    if (fetched case Err(failure: RateLimitFailure(:final retryAfter?))) _pauseAccount(id, retryAfter);
    return fetched;
  }

  /// True while the Provider's pause holds; a lapsed pause is forgotten.
  bool _paused(String id) {
    if (_pausedUntil[id] case final until?) {
      if (_clock.now().isBefore(until)) return true;
      _pausedUntil.remove(id);
    }
    return false;
  }

  /// Sends the Account's queue, in its turn, unless it may not go to the Provider now.
  Future<void> _replayIfActive(String accountId) async {
    if (await _activeAccount(accountId) case final account?) {
      await _serial(accountId, () => _replay(accountId, providerFor(account)));
    }
  }

  /// The Azioni, the sync, then the Bozze and the outbox; [synced] completes before these last two.
  Future<void> _syncOnce(Account account, Completer<void> synced) async {
    final accountId = account.id;
    try {
      // Removed while this sync waited in the queue (#174): nothing of it is written again, and its adapter, already
      // dropped, is not created again.
      if (await _account(accountId) == null) return;
      final provider = providerFor(account);
      try {
        // The Azioni first: a value changed elsewhere since they were queued is a Conflitto, not overwritten (ADR 0008).
        if (!_paused(accountId)) await _intents.replayActions(accountId, provider);
        if (!_paused(accountId)) await _syncPhase(accountId, provider);
        synced.complete();
      } catch (e, s) {
        synced.completeError(e, s);
        rethrow;
      } finally {
        // After the sync phase, failed too: a pull-to-refresh does not wait for Bozze MIME uploads nor outbox
        // attachments. Not once the sync made the Account Da ricollegare: its queue waits (ADR 0008).
        if (await _activeAccount(accountId) != null) {
          await _intents.replayDrafts(accountId, provider);
          if (!_paused(accountId)) await _outbox.sendDue(accountId, provider);
        }
      }
    } finally {
      // Only now: a pull during the replay joins this finished sync phase instead of queuing one behind the uploads.
      unawaited(_runningSync.remove(accountId));
      if (!synced.isCompleted) synced.complete();
    }
  }

  Future<void> _syncPhase(String accountId, MailProvider provider) async {
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
        // The cursor is saved here, from the complete batch: pages alone never save it.
        await _store.applySync(accountId, value, fullSnapshot: full);
        await _newMail.notify(accountId, fresh);
        // Not awaited: its replay goes through the Account's queue, which this sync holds until it ends.
        if (unknown.isNotEmpty) {
          final run = _labeler.queueAutoLabels(accountId, unknown, value.bodies);
          unawaited(autoLabeling[accountId] = run.then((queued) => queued ? _replayIfActive(accountId) : null));
        }
        debugPrint(
          '[sync] $accountId: ${full ? 'initial' : 'incremental'} sync end, '
          '${value.messages.length} messages, ${value.removedMessageIds.length} removed',
        );
      case Err(:final failure):
        debugPrint('[sync] $accountId: failed, $failure');
        _log.failure('sync $accountId', failure);
        if (failure case RateLimitFailure(:final retryAfter?)) {
          _pauseAccount(accountId, retryAfter);
          debugPrint('[sync] $accountId: paused until $retryAfter');
        }
        // ponytail: a fixed retry on the next poll; exponential backoff if Providers keep refusing.
        if (failure is AuthFailure) {
          await _store.setStatus(accountId, AccountStatus.daRicollegare);
        }
    }
  }
}

/// A queued sync: `done` when its whole slot ends, `synced` at the end of its sync phase.
typedef _QueuedSync = ({Future<void> done, Future<void> synced});

@module
abstract class SyncModule() {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
