import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'sync/sync_owner.dart';
import 'sync_engine.dart';

/// The background sync (#212), once the isolate has wired the app's DI (`sendOutboxDispatcher` in main.dart): Android's
/// periodic WorkManager task now, iOS (#213) and the Notifiche immediate (#214) later. With the app alive it only asks
/// the app to sync; otherwise one incremental sync of every attivo Account, its notifications, the replay and the due
/// outbox, and it ends. Always true: a failure waits for the next run, no WorkManager retry.
/// [answerWithin] stands for the owner's default in tests.
Future<bool> runSyncTask({Duration? answerWithin}) => _running = _run(answerWithin);

Future<bool> _run(Duration? answerWithin) async {
  final claim = answerWithin == null ? SyncOwner() : SyncOwner(answerWithin: answerWithin);
  try {
    if (!await claim.tryClaim()) return true;
    try {
      await GetIt.I<SyncEngine>().syncInBackground();
    } finally {
      claim.release();
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
