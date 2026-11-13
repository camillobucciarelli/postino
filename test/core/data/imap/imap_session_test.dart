// ImapSession.close while a session is logging in (#191): the removal of the Account closes it, the login in flight
// is not kept nor left hanging.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_failure.dart';
import 'package:postino/core/data/imap/imap_session.dart';

import '../../../support/fake_platform.dart';
import '../../../support/recorded_imap_server.dart';

const _id = 'imap:ada@example.org';

void main() {
  late FakeSecureStore keychain;
  late RecordedImapServer server;

  Future<void> start(ImapScript script) async {
    keychain = FakeSecureStore();
    server = await RecordedImapServer.start(script);
    addTearDown(server.stop);
    await server.remember(keychain, _id);
  }

  int logins() => server.commands.where((c) => c.startsWith('LOGIN')).length;

  test('closed while connecting: the login that ends afterwards is not kept', () async {
    await start((c) => basics(c, capabilities: 'IMAP4rev1')!);
    final connecting = Completer<void>();
    final release = Completer<void>();
    final session = ImapSession(
      _id,
      'ada@example.org',
      keychain,
      connect: (c, s) async {
        if (!connecting.isCompleted) connecting.complete();
        await release.future;
        await plainConnector(c, s);
      },
    );
    final run = session.run((_) async => 'ran');
    await connecting.future;

    await session.close();
    release.complete();

    await expectLater(run, throwsA(isA<ImapFailed>()));
    // Not left logged in: the next command logs in again.
    final before = logins();
    expect(await session.run((_) async => 'again'), 'again');
    expect(logins(), before + 1);
  });

  test('closed while connecting: no LOGIN is sent afterwards, even if the server then stalls', () async {
    await start((c) => c.startsWith('CAPABILITY') ? hang : basics(c, capabilities: 'IMAP4rev1')!);
    final connecting = Completer<void>();
    final release = Completer<void>();
    final session = ImapSession(
      _id,
      'ada@example.org',
      keychain,
      connect: (c, s) async {
        connecting.complete();
        await release.future;
        await plainConnector(c, s);
      },
    );
    final run = session.run((_) async => 'ran');
    await connecting.future;

    await session.close();
    release.complete();

    // Without the check before LOGIN the session logs in and waits on CAPABILITY for ImapSession.timeout.
    await expectLater(run.timeout(const Duration(seconds: 10)), throwsA(isA<ImapFailed>()));
    expect(logins(), 0);
  });

  test('closed while the server has not answered LOGIN: the session is dropped, not left waiting', () async {
    final login = Completer<void>();
    await start((c) {
      if (!c.startsWith('LOGIN')) return basics(c, capabilities: 'IMAP4rev1')!;
      login.complete();
      return hang;
    });
    final session = ImapSession(_id, 'ada@example.org', keychain, connect: plainConnector);
    final run = session.run((_) async => 'ran');
    await login.future;

    await session.close();

    // Without the close the login waits for ImapSession.timeout (2 minutes).
    await expectLater(run.timeout(const Duration(seconds: 10)), throwsA(isA<ImapFailed>()));
  });
}
