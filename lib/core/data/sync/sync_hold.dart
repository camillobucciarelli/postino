import 'account_queue.dart';
import 'sync_owner.dart';

/// The app's hold on the sync (#212): claimed at [start], claimed back when lost, given up at [stop]. The Account
/// queues wait for it, so nothing goes to a Provider while a background task syncs.
class SyncHold(
  final SyncOwner _owner,
  final AccountQueue _queue, {
  required final Future<void> Function() _onAsked,
  required final void Function() _onOwned,
}) {
  /// [_onAsked]: a background task's ask; [_onOwned]: once owned, before any queued work (the streams read again what
  /// the task wrote).
  this;

  bool _held = false;
  bool _claiming = false;
  Future<void> _owned = Future<void>.value();

  /// Completes once the app owns the sync; at once outside [start] and [stop].
  Future<void> get owned => _owned;

  void start() {
    _held = true;
    _claim();
  }

  void stop() {
    _held = false;
    _owner.release();
  }

  /// The name taken over while this did not answer in time (another engine of the app; a background task never
  /// takes it): claimed back before the next sync.
  void ensure() {
    if (_held && !_claiming && !_owner.owns) _claim();
  }

  void _claim() {
    _claiming = true;
    final owned = _owned = _owner
        .claim(onAsked: _onAsked)
        .then((_) => _onOwned())
        .whenComplete(() => _claiming = false);
    _queue.after(owned);
  }
}
