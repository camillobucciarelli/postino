import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

/// The name the owner of the sync registers its port under, process-wide.
const syncOwnerName = 'postino.sync';

/// The one owner of the sync among the isolates of the process (#212): the app's and the background task's (WorkManager
/// on Android, #213 on iOS). The owner registers a port with [IsolateNameServer]; the others find it there. Two syncs
/// of the same Account never run at once: the background task syncs only when nobody owns and never takes a name
/// over, and the app waits for the task to end. No table: the registry lives as long as the process, as both isolates do.
class SyncOwner({
  final String _name = syncOwnerName,
  final Duration _answerWithin = const Duration(seconds: 15),
  final Duration _syncWithin = const Duration(minutes: 5),
  final Duration _retryEvery = const Duration(seconds: 1),
}) {
  /// [_answerWithin]: how long a live owner takes to answer at most. [_syncWithin]: how long an ask waits for the
  /// owner's sync, within WorkManager's 10 minutes.
  this;

  RawReceivePort? _port;

  /// The background task registers its port under this name too: the app tells it from an engine of its own.
  String get _workerName => '$_name.worker';

  /// Set by [release]: a [claim] still waiting gives up.
  bool _released = false;

  /// True while this one holds the name: a late answer may have let another isolate take it over.
  bool get owns => switch (_port) {
    final port? => IsolateNameServer.lookupPortByName(_name) == port.sendPort,
    null => false,
  };

  /// Owns the sync if nobody does, true then. Otherwise false, once the owner synced as asked (or [_syncWithin]
  /// passed): [onAsked] runs on the owner for each ask, and its end is the answer. Waiting for it keeps the background
  /// task, and with it the process and its network, alive while the app syncs.
  /// A registered owner that does not answer within [_answerWithin] may be slow, not dead: a timeout stops nothing it
  /// started. Without [takeOver] (the background task) it keeps the name and this is false: the task skips its turn.
  /// With it (the app) a silent name of an engine of the app's own is taken (Android destroyed it, its isolate with it;
  /// the process lives on), a background task's never: no timeout proves it stopped, so the app waits for its release,
  /// which comes before WorkManager destroys its engine (at its end, or when stopped: `stopSyncTask`).
  // ponytail: a task whose engine the plugin destroys without the stop callback (its own failure path) leaves the name:
  // the app waits until the process restarts. An engine of the app destroyed while the process lives (Back on Android
  // 11 and earlier) leaves the app's: the background checks pause until the app opens again. A lease in the database
  // if either is ever seen.
  Future<bool> tryClaim({Future<void> Function()? onAsked, bool takeOver = false}) async {
    for (;;) {
      final port = RawReceivePort((Object? message) {
        if (message is! SendPort) return;
        message.send(true);
        unawaited(Future.sync(() => onAsked?.call()).catchError((Object _) {}).whenComplete(() => message.send(false)));
      });
      // The background task's mark goes first: whoever sees its name sees it is a task's.
      // ponytail: a mark left by a task gone without its release keeps the next tasks off until the process restarts.
      final marked = !takeOver && IsolateNameServer.registerPortWithName(port.sendPort, _workerName);
      if ((takeOver || marked) && IsolateNameServer.registerPortWithName(port.sendPort, _name)) {
        _port = port;
        return true;
      }
      if (marked) IsolateNameServer.removePortNameMapping(_workerName);
      port.close();
      final owner = IsolateNameServer.lookupPortByName(_name);
      // Free, but another task's mark is there (it is taking the name, or left the mark): this task skips its turn.
      if (owner == null && !takeOver && !marked) return false;
      if (owner == null) continue;
      if (await _ask(owner) || !takeOver) return false;
      if (IsolateNameServer.lookupPortByName(_workerName) == owner) return false;
      // ponytail: check-then-remove, not atomic; two isolates taking over the same stale name at once is the ceiling.
      if (IsolateNameServer.lookupPortByName(_name) == owner) IsolateNameServer.removePortNameMapping(_name);
    }
  }

  /// Waits until nobody else owns, then owns (the app: a background task running ends within seconds), taking over a
  /// silent name; nothing once [release]d meanwhile.
  Future<void> claim({Future<void> Function()? onAsked}) async {
    _released = false;
    while (!await tryClaim(onAsked: onAsked, takeOver: true)) {
      if (_released) return;
      await Future<void>.delayed(_retryEvery);
      if (_released) return;
    }
    if (_released) release();
  }

  /// Gives the sync up; the name stays with whoever took it over meanwhile.
  void release() {
    _released = true;
    final port = _port;
    if (port == null) return;
    _port = null;
    for (final name in [_name, _workerName]) {
      if (IsolateNameServer.lookupPortByName(name) == port.sendPort) IsolateNameServer.removePortNameMapping(name);
    }
    port.close();
  }

  /// True when [owner] answered: alive, and done with the sync asked or out of time for it.
  Future<bool> _ask(SendPort owner) async {
    final reply = ReceivePort();
    final answers = StreamIterator(reply);
    try {
      owner.send(reply.sendPort);
      if (!await answers.moveNext().timeout(_answerWithin)) return false;
      await answers.moveNext().timeout(_syncWithin, onTimeout: () => false);
      return true;
    } on TimeoutException {
      return false;
    } finally {
      reply.close();
    }
  }
}
