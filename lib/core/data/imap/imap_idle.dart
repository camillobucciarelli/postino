import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';

import '../../domain/mail_provider.dart';

/// Opens IMAP IDLE on the inbox of [user] at [host] (XOAUTH2), used only as a change signal (ADR 0008).
typedef ImapIdle = Stream<ChangeSignal> Function({
  required String host,
  required String user,
  required Future<String> Function() accessToken,
});

/// Gmail drops an IDLE after about 29 minutes: it is renewed before that.
const _renewIdle = Duration(minutes: 25);

/// Reconnects for as long as it is listened to; never throws, a failure is [ChangeSignal.down].
// ponytail: fixed 30 s between reconnections; backoff if servers start refusing.
Stream<ChangeSignal> imapIdle({
  required String host,
  required String user,
  required Future<String> Function() accessToken,
}) {
  var stopped = false;
  ImapClient? client;
  Completer<void>? wake;
  Timer? timer;
  late final StreamController<ChangeSignal> out;

  Future<void> sleep(Duration d) {
    final w = wake = Completer<void>();
    timer = Timer(d, () => w.isCompleted ? null : w.complete());
    return w.future;
  }

  Future<void> run() async {
    while (!stopped) {
      final c = client = ImapClient();
      StreamSubscription<ImapEvent>? events;
      try {
        await c.connectToServer(host, 993);
        await c.authenticateWithOAuth2(user, await accessToken());
        await c.selectInbox();
        final lost = Completer<void>();
        events = c.eventStream.listen((e) {
          if (e is ImapConnectionLostEvent) {
            if (!lost.isCompleted) lost.complete();
          } else if (e is ImapMessagesExistEvent ||
              e is ImapExpungeEvent ||
              e is ImapVanishedEvent ||
              e is ImapFetchEvent) {
            out.add(ChangeSignal.changed);
          }
        });
        out.add(ChangeSignal.up);
        while (!stopped && !lost.isCompleted) {
          await c.idleStart();
          await Future.any([sleep(_renewIdle), lost.future]);
          timer?.cancel();
          if (stopped || lost.isCompleted) break;
          await c.idleDone();
        }
      } catch (e) {
        // Down below, and retried.
        debugPrint('[idle] $user: $e');
      } finally {
        await events?.cancel();
        unawaited(c.disconnect().catchError((_) {}));
      }
      if (stopped) break;
      out.add(ChangeSignal.down);
      await sleep(const Duration(seconds: 30));
    }
  }

  out = StreamController<ChangeSignal>(
    onListen: () => unawaited(run()),
    onCancel: () {
      stopped = true;
      timer?.cancel();
      if (wake case final w? when !w.isCompleted) w.complete();
      unawaited(client?.disconnect().catchError((_) {}));
    },
  );
  return out.stream;
}
