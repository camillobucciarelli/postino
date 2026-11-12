import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'sync/sync_owner.dart';
import 'sync_engine.dart';

/// The background sync (#212), once the isolate has wired the app's DI (`sendOutboxDispatcher` in main.dart): Android's
/// periodic WorkManager task and iOS's BGAppRefreshTask (#213), the the Notifiche immediate (#214) later. With the app alive it only asks
/// the app to sync; otherwise one incremental sync of every attivo Account, its notifications, the replay and the due
/// outbox, and it ends. Always true: a failure waits for the next run, no WorkManager retry.
/// [answerWithin] stands for the owner's default in tests.
///
/// [budget] (iOS, #213: [iosBudget]) is the time the system gives: past it no new Account starts and the task ends
/// without waiting for the ones still syncing; they never write half a sync, so they resume next time.
Future<bool> runSyncTask({Duration? answerWithin, Duration? budget}) => _running = _run(answerWithin, budget);

/// What the task uses of the ~30 s iOS gives a BGAppRefreshTask, leaving the rest to end it before it expires.
const iosBudget = Duration(seconds: 25);

Future<bool> _run(Duration? answerWithin, Duration? budget) async {
  final claim = answerWithin == null ? SyncOwner() : SyncOwner(answerWithin: answerWithin);
  try {
    if (!await claim.tryClaim()) return true;
    final sync = GetIt.I<SyncEngine>().syncInBackground(budget: budget);
    var ended = false;
    unawaited(sync.then<void>((_) => ended = true, onError: (_) => ended = true));
    try {
      // ponytail: real time here, the engine's clock for the starts; a sync cut off keeps running until iOS suspends.
      await (budget == null ? sync : sync.timeout(budget, onTimeout: () {}));
    } finally {
      // A sync cut off by the budget still runs: the name stays with it until it ends, so the app never syncs next to it.
      if (ended) {
        claim.release();
      } else {
        unawaited(sync.then<void>((_) {}, onError: (_) {}).whenComplete(claim.release));
      }
    }
  } on Object catch (e) {
    // The type only: the error may quote a message or a server's answer.
    debugPrint('[background] sync failed, ${e.runtimeType}');
  }
  return true;
}

/// The task, while it runs.
Future<bool>? _running;

/// WorkManager stops the task (#212: constraints lost, its 10 minutes over) and destroys its engine once this returns:
/// the sync running ends first, then its name goes; the app, waiting for that name, never syncs next to it, and does
/// not wait for it until the process restarts.
// ponytail: the sync is not cut short; each Provider call has its own timeout, within the minutes WorkManager allows.
Future<void> stopSyncTask() async => _running;
