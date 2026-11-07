import 'dart:async';
import 'dart:io' show X509Certificate;

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';

import '../../domain/mail_provider.dart';
import '../../domain/mail_servers.dart';
import 'imap_session.dart';

/// Opens IMAP IDLE on the inbox of [user] at [host], used only as a change signal (ADR 0008): with XOAUTH2 when
/// [accessToken] is given (Gmail), else with LOGIN and [password] (iCloud and IMAP).
typedef ImapIdle = Stream<ChangeSignal> Function({
  required String host,
  required String user,
  int port,
  ServerSecurity security,
  Future<String> Function()? accessToken,
  Future<String> Function()? password,
  bool Function(X509Certificate)? onBadCertificate,
  ImapConnector connect,
});

/// Gmail drops an IDLE after about 29 minutes: it is renewed before that.
const _renewIdle = Duration(minutes: 25);

/// Reconnects for as long as it is listened to; never throws, a failure is [ChangeSignal.down]. A server without
/// IDLE stays [ChangeSignal.down] for good: the sync engine's 60 s poll covers it.
// ponytail: fixed 30 s between reconnections; backoff if servers start refusing.
Stream<ChangeSignal> imapIdle({
  required String host,
  required String user,
  int port = 993,
  ServerSecurity security = ServerSecurity.ssl,
  Future<String> Function()? accessToken,
  Future<String> Function()? password,
  bool Function(X509Certificate)? onBadCertificate,
  ImapConnector connect = connectImap,
}) {
  assert((accessToken == null) != (password == null), 'either an access token or a password');
  var stopped = false;
  ImapClient? client;
  Completer<void>? wake;
  Timer? timer;
  // ignore: close_sinks, the listener's cancel ends the stream (onCancel stops the loop).
  late final StreamController<ChangeSignal> out;

  Future<void> sleep(Duration d) {
    final w = wake = Completer<void>();
    timer = Timer(d, () => w.isCompleted ? null : w.complete());
    return w.future;
  }

  Future<void> run() async {
    while (!stopped) {
      final c = client = ImapClient(onBadCertificate: onBadCertificate);
      StreamSubscription<ImapEvent>? events;
      try {
        await connect(c, MailServer(host: host, port: port, security: security));
        if (accessToken != null) {
          await c.authenticateWithOAuth2(user, await accessToken());
        } else {
          await c.login(user, await password!());
          if (!(await c.capability()).any((x) => x.name.toUpperCase() == 'IDLE')) {
            debugPrint('[idle] $user: no IDLE, polling');
            out.add(ChangeSignal.down);
            return;
          }
        }
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
      } on Object catch (e) {
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
