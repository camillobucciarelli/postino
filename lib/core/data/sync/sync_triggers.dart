import 'dart:async';

import '../../domain/account.dart';
import '../../domain/mail_provider.dart';
import '../../domain/platform_services.dart';
import '../mail_store.dart';
import 'provider_factory.dart';

/// Polling period: the change signal watches only the inbox, so the poll also brings Bozze and the rest (ADR 0008).
const pollEvery = Duration(seconds: 60);

/// What starts a sync (ADR 0008): each attivo Account's change signal (IDLE), the poll every [pollEvery] and the
/// network coming back.
class SyncTriggers(
  final MailStore _store,
  final Clock _clock,
  final Connectivity _connectivity, {
  required final Future<void> Function() _syncAll,
  required final Future<void> Function() _poll,
  required final Future<void>? Function(Account account) _sync,

  /// The Account's removal is running (#174): no change signal for it.
  required final bool Function(String accountId) _removalRunning,
}) {
  /// `syncAll` runs when the network returns, `poll` on every tick, `sync` on an Account's change signal.
  this;

  final _subs = <StreamSubscription<Object?>>[];
  final _signals = <String, StreamSubscription<ChangeSignal>>{};

  void start() {
    _subs
      ..add(_store.watchAccounts().listen(_watchSignals))
      ..add(_clock.every(pollEvery).listen((_) => _poll()))
      ..add(
        _connectivity.onChanged.listen((online) {
          if (online) unawaited(_syncAll());
        }),
      );
  }

  Future<void> stop() async {
    await Future.wait([
      for (final s in [..._subs, ..._signals.values]) s.cancel(),
    ]);
    _subs.clear();
    _signals.clear();
  }

  /// Stops the Account's change signal (IDLE). Not awaited: ending IDLE may wait on the network.
  void forget(String accountId) => unawaited(_signals.remove(accountId)?.cancel());

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
      if (_removalRunning(a.id)) continue;
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
}
