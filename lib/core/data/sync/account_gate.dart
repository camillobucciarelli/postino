import '../../domain/account.dart';
import '../../domain/platform_services.dart';
import '../mail_store.dart';

/// Whether an Account's queue may go to the Provider now: the Provider's pause (a rate limit, ADR 0008) and the
/// Rimozione dell'Account (#174). One per sync engine, shared by everything it runs for the Account.
class AccountGate(final MailStore _store, final Clock _clock) {
  /// The pause for a rate limit with no end given (#394): this first, doubled by each next one up to [_maxBackoff].
  static const _firstBackoff = Duration(seconds: 60);
  static const _maxBackoff = Duration(minutes: 15);

  /// Accounts the Provider blocked until a given time: no sync before it.
  final _pausedUntil = <String, DateTime>{};

  /// Per Account, its next pause for a rate limit with no end given.
  final _backoff = <String, Duration>{};

  /// Accounts whose removal started (#174), true once their data is deleted: their queue sends nothing more, and
  /// what was downloading for them is not written (set before the delete, so a check right before a write is
  /// enough). The entry goes when the same Account is connected again.
  final _removing = <String, bool>{};

  Future<Account?> find(String id) async => (await _store.accounts()).where((a) => a.id == id).firstOrNull;

  /// The Account if its queue may go to the Provider now: not paused, not Da ricollegare (it waits for the reconnection).
  /// Never once its removal started (#174).
  Future<Account?> active(String id) async {
    if (paused(id) || removed(id)) return null;
    final account = await find(id);
    return account?.status == AccountStatus.attivo ? account : null;
  }

  /// The Provider rate-limited the Account: no sync nor send before [until].
  void pause(String id, DateTime until) => _pausedUntil[id] = until;

  /// The Provider rate-limited a sync: paused until [retryAfter], or without one for the Account's backoff, which
  /// doubles each time until [resetBackoff] (#394). The end of the pause.
  DateTime rateLimited(String id, DateTime? retryAfter) {
    var until = retryAfter;
    if (until == null) {
      final wait = _backoff[id] ?? _firstBackoff;
      _backoff[id] = wait * 2 > _maxBackoff ? _maxBackoff : wait * 2;
      until = _clock.now().add(wait);
    }
    pause(id, until);
    return until;
  }

  /// A sync went through with no rate limit: the next pause starts from the first backoff again.
  void resetBackoff(String id) => _backoff.remove(id);

  /// The end of the Account's pause, if one was set.
  DateTime? pausedUntil(String id) => _pausedUntil[id];

  /// True while the Provider's pause holds; a lapsed pause is forgotten.
  bool paused(String id) {
    if (_pausedUntil[id] case final until?) {
      if (_clock.now().isBefore(until)) return true;
      _pausedUntil.remove(id);
    }
    return false;
  }

  /// True once the Account's removal started (#174): nothing more goes to its Provider nor is written.
  bool removed(String id) => _removing.containsKey(id);

  void removalStarted(String id) => _removing[id] = false;

  /// Not removed after all: the Account works again.
  void removalFailed(String id) => _removing.remove(id);

  void removalDone(String id) {
    _removing[id] = true;
    _pausedUntil.remove(id);
    _backoff.remove(id);
  }

  /// True while the Account's removal runs (it is still listed); a removed Account listed again is connected anew,
  /// so its removal is forgotten.
  bool removalRunning(String id) {
    if (_removing[id] == false) return true;
    _removing.remove(id);
    return false;
  }
}
