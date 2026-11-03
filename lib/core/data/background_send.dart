import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:workmanager/workmanager.dart';

import '../../main.dart';
import 'sync_engine.dart';

/// Android WorkManager entry point (#36): a fresh isolate wires the app's DI and sends the Account's due outbox.
/// The database may be open in the main isolate too; SQLite's locking serialises the two connections.
// ponytail: a row due in both isolates at once may be sent by both; the Provider's Message-ID check makes the second a no-op.
@pragma('vm:entry-point')
void sendOutboxDispatcher() {
  Workmanager().executeTask((task, input) async {
    final accountId = input?['accountId'] as String?;
    if (accountId == null) return true;
    try {
      DartPluginRegistrant.ensureInitialized();
      await configureDependencies(environment: Environment.prod);
      await getIt<SyncEngine>().flushOutbox(accountId);
    } catch (e) {
      debugPrint('[background] $accountId: send failed, $e');
    }
    // What did not go stays queued for the next app start; no WorkManager retry.
    return true;
  });
}
