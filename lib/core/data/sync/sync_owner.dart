import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

/// The name the owner of the sync registers its port under, process-wide.
const syncOwnerName = 'postino.sync';

/// The one owner of the sync among the isolates of the process (#212): the app's and the background task's (WorkManager
/// on Android, #213 on iOS). The owner registers a port with [IsolateNameServer]; the others find it there. Two syncs
/// of the same Account never run at once: the background task syncs only when nobody owns, and the app waits for the
/// task to end. No table: the registry lives as long as the process, as both isolates do.
class SyncOwner({
  final String _name = syncOwnerName,
  final Duration _answerWithin = const Duration(seconds: 15),
  final Duration _syncWithin = const Duration(minutes: 5),
  final Duration _retryEvery = const Duration(seconds: 1),
}) {
  /// [_answerWithin]: how long a live owner takes to answer at most; one that does not is gone, its isolate ended
  /// without releasing (Android destroys the Activity's engine, the process lives on). [_syncWithin]: how long an
  /// ask waits for the owner's sync, within WorkManager's 10 minutes.
  this;

  RawReceivePort? _port;

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
  Future<bool> tryClaim({Future<void> Function()? onAsked}) async {
    for (;;) {
      final port = RawReceivePort((Object? message) {
        if (message is! SendPort) return;
        message.send(true);
        unawaited(Future.sync(() => onAsked?.call()).catchError((Object _) {}).whenComplete(() => message.send(false)));
      });
      if (IsolateNameServer.registerPortWithName(port.sendPort, _name)) {
        _port = port;
        return true;
      }
      port.close();
      final owner = IsolateNameServer.lookupPortByName(_name);
      if (owner == null) continue;
      if (await _ask(owner)) return false;
      // ponytail: check-then-remove, not atomic; two isolates taking over the same stale name at once is the ceiling.
      if (IsolateNameServer.lookupPortByName(_name) == owner) IsolateNameServer.removePortNameMapping(_name);
    }
  }

  /// Waits until nobody else owns, then owns (the app: a background task running ends within seconds); nothing once
  /// [release]d meanwhile.
  Future<void> claim({Future<void> Function()? onAsked}) async {
    _released = false;
    while (!await tryClaim(onAsked: onAsked)) {
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
    if (IsolateNameServer.lookupPortByName(_name) == port.sendPort) IsolateNameServer.removePortNameMapping(_name);
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
