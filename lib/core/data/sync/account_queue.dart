import 'dart:async';

/// A queued sync: `done` when its whole slot ends, `synced` at the end of its sync phase.
typedef QueuedSync = ({Future<void> done, Future<void> synced});

/// The one serial queue per Account (ADR 0008): syncs, Conversazione hydrations and replays run one after the
/// other, so none applies a Provider answer older than one already applied.
class AccountQueue() {
  /// Per Account, the tail of its serial queue.
  final _tail = <String, Future<void>>{};

  /// Per Account, the sync waiting in the queue: more requests join it instead of piling up.
  /// `synced` completes at the end of its sync phase, before the Bozze and outbox go.
  final _queuedSync = <String, QueuedSync>{};

  /// Per Account, the sync phase of the sync running now (finished once it reaches the Bozze and the outbox):
  /// a pull-to-refresh waits for it instead of queuing another.
  final _runningSync = <String, Future<void>>{};

  /// What every Account's queue waits for first: the app's ownership of the sync (#212).
  Future<void> _ready = Future<void>.value();

  /// Nothing queued, now or later, runs before [ready]: a background sync running keeps the app's waiting (#212).
  void after(Future<void> ready) {
    _ready = ready;
    _tail.updateAll((_, tail) => tail.then((_) => ready));
  }

  /// Runs [op] after everything already queued for the Account; a failure does not block the queue.
  Future<T> run<T>(String accountId, Future<T> Function() op) {
    final run = (_tail[accountId] ?? _ready).then((_) => op());
    _tail[accountId] = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Queues [sync] for the Account; requests made before it starts share it, a request while it runs queues another.
  /// [sync] completes `synced` at the end of its sync phase; if it does not, `synced` completes when [sync] ends.
  QueuedSync sync(String id, Future<void> Function(Completer<void> synced) sync) {
    if (_queuedSync[id] case final queued?) return queued;
    final synced = Completer<void>();
    // A failure reaches the callers through `done` too: with no pull listening it is not reported twice.
    synced.future.ignore();
    final done = run(id, () async {
      _queuedSync.remove(id);
      _runningSync[id] = synced.future;
      try {
        await sync(synced);
      } finally {
        // Only now: a pull during the replay joins this finished sync phase instead of queuing one behind the uploads.
        unawaited(_runningSync.remove(id));
        if (!synced.isCompleted) synced.complete();
      }
    });
    return _queuedSync[id] = (done: done, synced: synced.future);
  }

  /// The sync phase of the Account's sync running now, if any.
  Future<void>? running(String id) => _runningSync[id];
}
