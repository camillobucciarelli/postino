import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../domain/mail_sync.dart';
import '../domain/notification_action.dart';
import '../domain/notification_action_use_case.dart';
import 'sync/sync_owner.dart';

/// A notification's button in a background engine with the app not running (#211), once the isolate has wired the
/// app's DI (`notificationActionDispatcher` in main.dart). The Azione is queued and applied here first: the queued voce
/// keeps a sync's older batch from undoing it (ADR 0008). Then, as `runSyncTask` does (#212), it goes to the Provider
/// only from the owner of the sync: owning it, the Azioni alone (the Bozze have no cross-isolate claim), and the name
/// goes back at the end; a background task owning it, the voce waits for that task's or the next replay.
/// [answerWithin] stands for the owner's default in tests.
// ponytail: a task already past its replay leaves the voce for the next run or the app's start; ask it to replay if seen.
Future<void> runNotificationActionTask(NotificationActionTap tap, {Duration? answerWithin}) async {
  final accountId = tap.conversation.accountId;
  try {
    await GetIt.I<NotificationActionUseCase>().run(tap, replay: false);
    final owner = answerWithin == null ? SyncOwner() : SyncOwner(answerWithin: answerWithin);
    if (!await owner.tryClaim()) return;
    try {
      await GetIt.I<MailSync>().replayActions(accountId);
    } finally {
      owner.release();
    }
  } on Object catch (e) {
    // The type only: the error may quote the message.
    debugPrint('[notifiche] $accountId: action failed, ${e.runtimeType}');
  }
}
