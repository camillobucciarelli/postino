import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/mail_provider.dart';
import '../domain/mail_sync.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'gmail/gmail_provider.dart';
import 'mail_store.dart';

/// Polling period while an Account's change signal is down (ADR 0008).
const pollEvery = Duration(seconds: 60);

/// Sync engine (ADR 0008): initial sync once per Account, then incremental from the saved cursor
/// whenever the change signal fires, every [pollEvery] while it is down, and when the network returns.
@lazySingleton
class SyncEngine implements MailSync {
  SyncEngine(this._store, this._clock, this._connectivity);
  final MailStore _store;
  final Clock _clock;
  final Connectivity _connectivity;

  final _subs = <StreamSubscription<Object?>>[];
  final _signals = <String, StreamSubscription<ChangeSignal>>{};

  /// Accounts whose change signal is up: the poll skips them.
  final _signalUp = <String>{};

  /// Accounts whose last sync failed for a passing reason (offline, rate limit): the poll retries them.
  final _retry = <String>{};

  /// Accounts the Provider blocked until a given time: no sync before it.
  final _pausedUntil = <String, DateTime>{};
  final _running = <String, Future<void>>{};
  final _again = <String>{};

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
      for (final s in [..._subs, ..._signals.values]) s.cancel(),
    ]);
    _subs.clear();
    _signals.clear();
    _signalUp.clear();
  }

  @override
  Future<void> syncAll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        // A Da ricollegare Account stops syncing until the user consents again.
        if (account.status == AccountStatus.attivo) _sync(account),
    ]);
  }

  @override
  Future<void> openConversation(String accountId, String conversationId) async {
    final account = await _account(accountId);
    if (account == null) return;
    final provider = _provider(account);
    // Read here at once, offline too; the Provider hears it from the queue.
    await _store.markConversationRead(accountId, conversationId);
    // Inviati and messages older than the sync window are not in the database yet.
    // ponytail: refetched on every opening (one request); remember complete Conversazioni if the quota ever matters.
    if (await provider.fetchConversation(conversationId) case Ok(
      :final value,
    )) {
      await _store.applyPage(accountId, value, const {});
      await _store.markConversationRead(accountId, conversationId);
    }
    await _replay(accountId, provider);
  }

  @override
  Future<Result<void>> fetchBody(String accountId, String messageId) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    switch (await _provider(account).fetchBody(messageId)) {
      case Ok(:final value):
        await _store.saveBody(accountId, messageId, value);
        return const Ok(null);
      case Err(:final failure):
        debugPrint('[sync] $accountId: body $messageId failed, $failure');
        return Err(failure);
    }
  }

  Future<Account?> _account(String id) async =>
      (await _store.accounts()).where((a) => a.id == id).firstOrNull;

  final _replaying = <String, Future<void>>{};

  /// Sends the offline queue (ADR 0008); what fails stays queued for the next sync.
  /// One replay at a time per Account: a second caller waits for the running one, never resends.
  Future<void> _replay(String accountId, MailProvider provider) =>
      _replaying[accountId] ??=
          _replayOnce(
            accountId,
            provider,
            // A block body: returning the removed future would make whenComplete wait on itself.
          ).whenComplete(() {
            _replaying.remove(accountId);
          });

  Future<void> _replayOnce(String accountId, MailProvider provider) async {
    final byValue = <bool, List<String>>{};
    for (final i in await _store.pendingIntents(accountId)) {
      if (i.isRead case final read?) (byValue[read] ??= []).add(i.messageId);
    }
    for (final MapEntry(key: read, value: ids) in byValue.entries) {
      switch (await provider.setRead(ids, read: read)) {
        // Gone from the Provider: the intent is dropped in silence.
        case Ok() || Err(failure: NotFoundFailure()):
          await _store.readDone(accountId, ids, isRead: read);
        case Err(:final failure):
          debugPrint('[sync] $accountId: replay failed, $failure');
      }
    }
  }

  Future<void> _poll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        if (account.status == AccountStatus.attivo &&
            (!_signalUp.contains(account.id) || _retry.contains(account.id)))
          _sync(account),
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
        _signalUp.remove(id);
      }
    }
    for (final a in attivi.values) {
      if (_signals.containsKey(a.id)) continue;
      void down() => _signalUp.remove(a.id);
      _signals[a.id] = _provider(a).changes.listen(
        (signal) {
          switch (signal) {
            case ChangeSignal.up:
              _signalUp.add(a.id);
              // Whatever changed while it was down.
              unawaited(_sync(a));
            case ChangeSignal.changed:
              unawaited(_sync(a));
            case ChangeSignal.down:
              down();
          }
        },
        onError: (_) => down(),
        onDone: down,
      );
    }
  }

  /// The Account's adapter, created on first use; tests register fakes by Account id beforehand.
  MailProvider _provider(Account account) {
    final g = GetIt.I;
    if (!g.isRegistered<MailProvider>(instanceName: account.id)) {
      // ponytail: Gmail is the only Provider of step 1; Microsoft and IMAP adapters branch on account.provider at steps 4-5.
      g.registerLazySingleton<MailProvider>(
        () => GmailProvider(account.id, g(), g(), g()),
        instanceName: account.id,
      );
    }
    return g<MailProvider>(instanceName: account.id);
  }

  /// One sync at a time per Account; a request while one runs makes it run once more afterwards.
  Future<void> _sync(Account account) {
    final id = account.id;
    if (_pausedUntil[id] case final until?) {
      if (_clock.now().isBefore(until)) return Future.value();
      _pausedUntil.remove(id);
    }
    if (_running[id] case final running?) {
      _again.add(id);
      return running;
    }
    return _running[id] = () async {
      try {
        do {
          _again.remove(id);
          await _syncOnce(id, _provider(account));
        } while (_again.contains(id));
      } finally {
        _running.remove(id);
      }
    }();
  }

  Future<void> _syncOnce(String accountId, MailProvider provider) async {
    // The queue first, so the sync brings back what the user did offline.
    await _replay(accountId, provider);
    final cursor = await _store.cursor(accountId);
    var full = cursor == null;
    Future<Result<SyncBatch>> initial() {
      debugPrint('[sync] $accountId: initial sync start');
      return provider.initialSync(
        onPage: (messages, bodies) =>
            _store.applyPage(accountId, messages, bodies),
      );
    }

    if (!full) debugPrint('[sync] $accountId: incremental sync start');
    var result = full
        ? await initial()
        : await provider.incrementalSync(cursor);
    if (result case Err(failure: NotFoundFailure())) {
      // Expired cursor: start over.
      full = true;
      result = await initial();
    }
    switch (result) {
      case Ok(:final value):
        _retry.remove(accountId);
        // The cursor is saved here, from the complete batch: pages alone never save it.
        await _store.applySync(accountId, value, fullSnapshot: full);
        debugPrint(
          '[sync] $accountId: ${full ? 'initial' : 'incremental'} sync end, '
          '${value.messages.length} messages, ${value.removedMessageIds.length} removed',
        );
      case Err(:final failure):
        debugPrint('[sync] $accountId: failed, $failure');
        if (failure case RateLimitFailure(:final retryAfter?)) {
          _pausedUntil[accountId] = retryAfter;
          debugPrint('[sync] $accountId: paused until $retryAfter');
        }
        if (failure is AuthFailure) {
          _retry.remove(accountId);
          await _store.setStatus(accountId, AccountStatus.daRicollegare);
        } else {
          // ponytail: a fixed retry on the next poll; exponential backoff if Providers keep refusing.
          _retry.add(accountId);
        }
    }
  }
}

@module
abstract class SyncModule {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
