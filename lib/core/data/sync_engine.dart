import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/error_log.dart';
import '../domain/mail_provider.dart';
import '../domain/mail_sync.dart';
import '../domain/message.dart';
import '../domain/outbox_repository.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'mail_store.dart';
import 'sync/draft_opener.dart';
import 'sync/intent_replayer.dart';
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
  final ErrorLog _log,
) implements MailSync {
  late final _intents = IntentReplayer(_store, _outboxStore, _clock, _log);
  late final _drafts = DraftOpener(_store, _outboxStore);

  /// Its Annulla invio tickers call back [flushOutbox]: the sends still go through [_serial].
  late final _outbox = OutboxSender(
    _outboxStore,
    _clock,
    _background,
    _log,
    account: _account,
    flushOutbox: flushOutbox,
    pause: (id, until) => _pausedUntil[id] = until,
  );

  final _subs = <StreamSubscription<Object?>>[];
  final _signals = <String, StreamSubscription<ChangeSignal>>{};

  /// Accounts the Provider blocked until a given time: no sync before it.
  final _pausedUntil = <String, DateTime>{};

  /// Per Account, the tail of its serial queue: syncs, Conversazione hydrations and replays
  /// run one after the other, so none applies a Provider answer older than one already applied.
  final _tail = <String, Future<void>>{};

  /// Per Account, the sync waiting in the queue: more requests join it instead of piling up.
  final _queuedSync = <String, Future<void>>{};

  /// Per Account, the ticker that sends its Bozze once the edits pause.
  final _draftTimers = <String, StreamSubscription<void>>{};

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
      for (final s in [..._subs, ..._signals.values, ..._draftTimers.values]) s.cancel(),
      _outbox.stop(),
    ]);
    _subs.clear();
    _signals.clear();
    _draftTimers.clear();
  }

  @override
  Future<void> syncAll() async {
    // On resume the WorkManager isolate may have sent (or refused) outbox rows: the streams read the file again.
    // ponytail: only when syncAll runs (start, resume, network back); a cross-isolate notification if a worker ever writes while in foreground.
    _store.refreshAfterExternalWrites();
    await Future.wait([
      for (final account in await _store.accounts())
        // A Da ricollegare Account stops syncing until the user consents again.
        if (account.status == AccountStatus.attivo) _sync(account),
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
      final fetched = await provider.fetchConversation(conversationId);
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
    if (account == null) return const Err(NotFoundFailure());
    return providerFor(account).fetchAttachment(messageId, attachmentId, onProgress: onProgress, cancel: cancel);
  }

  @override
  Future<Result<Label>> createLabel(String accountId, String name) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    // In the Account's queue: a sync that read the list before the creation cannot drop it afterwards.
    return _serial(accountId, () async {
      final created = await providerFor(account).createLabel(name);
      if (created case Ok(:final value)) await _store.saveLabel(accountId, value);
      return created;
    });
  }

  @override
  Future<void> setLabel(String accountId, String messageId, String labelId, {required bool add}) async {
    await _store.queueLabel(accountId, messageId, labelId, add: add);
    if (await _activeAccount(accountId) case final account?) {
      await _serial(accountId, () => _replay(accountId, providerFor(account)));
    }
  }

  Future<Account?> _account(String id) async => (await _store.accounts()).where((a) => a.id == id).firstOrNull;

  /// The Account if its queue may go to the Provider now: not paused, not Da ricollegare (it waits for the reconnection).
  Future<Account?> _activeAccount(String id) async {
    if (_paused(id)) return null;
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
    // A send ahead of this one in the queue may have just paused the Account.
    if (_paused(accountId)) return;
    if (!outboxOnly) await _intents.replay(accountId, provider, flush: flush);
    await _outbox.sendDue(accountId, provider);
  }

  Future<void> _poll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        if (account.status == AccountStatus.attivo) _sync(account),
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
      if (_signals.containsKey(a.id)) continue;
      _signals[a.id] = providerFor(a).changes.listen((signal) {
        switch (signal) {
          // Up: whatever changed while it was down.
          case ChangeSignal.up || ChangeSignal.changed:
            unawaited(_sync(a));
          case ChangeSignal.down:
        }
      });
    }
  }

  /// Queues a sync of the Account; requests made before it starts share it, a request while it runs queues another.
  Future<void> _sync(Account account) {
    final id = account.id;
    if (_paused(id)) return Future.value();
    return _queuedSync[id] ??= _serial(id, () {
      // Only drops the map entry: the queued future is the one returned to the caller.
      unawaited(_queuedSync.remove(id));
      return _syncOnce(id, providerFor(account));
    });
  }

  /// True while the Provider's pause holds; a lapsed pause is forgotten.
  bool _paused(String id) {
    if (_pausedUntil[id] case final until?) {
      if (_clock.now().isBefore(until)) return true;
      _pausedUntil.remove(id);
    }
    return false;
  }

  Future<void> _syncOnce(String accountId, MailProvider provider) async {
    // The queue first, so the sync brings back what the user did offline.
    await _replay(accountId, provider);
    if (_paused(accountId)) return;
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
        // The cursor is saved here, from the complete batch: pages alone never save it.
        await _store.applySync(accountId, value, fullSnapshot: full);
        debugPrint(
          '[sync] $accountId: ${full ? 'initial' : 'incremental'} sync end, '
          '${value.messages.length} messages, ${value.removedMessageIds.length} removed',
        );
      case Err(:final failure):
        debugPrint('[sync] $accountId: failed, $failure');
        _log.failure('sync $accountId', failure);
        if (failure case RateLimitFailure(:final retryAfter?)) {
          _pausedUntil[accountId] = retryAfter;
          debugPrint('[sync] $accountId: paused until $retryAfter');
        }
        // ponytail: a fixed retry on the next poll; exponential backoff if Providers keep refusing.
        if (failure is AuthFailure) {
          await _store.setStatus(accountId, AccountStatus.daRicollegare);
        }
    }
  }
}

@module
abstract class SyncModule() {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
