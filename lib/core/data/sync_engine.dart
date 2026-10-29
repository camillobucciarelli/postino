import 'dart:async';

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
    final cursor = await _store.cursor(accountId);
    var full = cursor == null;
    var result = full
        ? await provider.initialSync()
        : await provider.incrementalSync(cursor);
    if (result case Err(failure: NotFoundFailure())) {
      // Expired cursor: start over.
      full = true;
      result = await provider.initialSync();
    }
    switch (result) {
      case Ok(:final value):
        _retry.remove(accountId);
        await _store.applySync(accountId, value, fullSnapshot: full);
      case Err(failure: AuthFailure()):
        _retry.remove(accountId);
        await _store.setStatus(accountId, AccountStatus.daRicollegare);
      // ponytail: a fixed retry on the next poll; exponential backoff if Providers keep refusing.
      case Err():
        _retry.add(accountId);
    }
  }
}

@module
abstract class SyncModule {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
