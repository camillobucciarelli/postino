import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'sync/sync_owner.dart';
import 'sync_engine.dart';

/// The background sync (#212), once the isolate has wired the app's DI (`sendOutboxDispatcher` in main.dart): Android's
/// periodic WorkManager task and iOS's BGAppRefreshTask (#213), the Notifiche immediate (#214) later. With the app alive it only asks
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
  Future<void> work() async {
    if (!await claim.tryClaim()) return;
    await GetIt.I<SyncEngine>().syncInBackground(budget: budget);
  }

  try {
    // The budget covers the handshake with the app too. ponytail: real time here, the engine's clock for the starts.
    await (budget == null ? work() : work().timeout(budget, onTimeout: () {}));
    // A batch already applied still notifies: its cursor moved, nothing would notify it later.
    if (budget != null) await GetIt.I<SyncEngine>().commitsSettled();
  } on Object catch (e) {
    // The type only: the error may quote a message or a server's answer.
    debugPrint('[background] sync failed, ${e.runtimeType}');
  } finally {
    // Before returning: the plugin destroys the engine then, and a name left behind would keep the app and the next
    // runs off the sync. A sync cut off by the budget dies with the engine; it never wrote half of itself.
    claim.release();
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
