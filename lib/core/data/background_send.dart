import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'sync_engine.dart';

/// The Android WorkManager task (#36), once the isolate has wired the app's DI (`sendOutboxDispatcher` in main.dart):
/// sends the Account's due outbox. The database may be open in the main isolate too: SQLite's locking serialises
/// the two connections, and each row is claimed in the database before it goes, so only one isolate sends it.
/// Always true: what did not go stays queued for the next app start; no WorkManager retry.
Future<bool> runOutboxTask(String accountId) async {
  try {
    await GetIt.I<SyncEngine>().flushOutbox(accountId);
  } catch (e) {
    debugPrint('[background] $accountId: send failed, $e');
  }
  return true;
}
