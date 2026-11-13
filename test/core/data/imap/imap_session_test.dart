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
    expect(logins(), lessThanOrEqualTo(1));
    // Not left logged in: the next command logs in again.
    expect(await session.run((_) async => 'again'), 'again');
    expect(logins(), 2);
  });

  test('closed while the server has not answered LOGIN: the session is dropped, not left waiting', () async {
    await start((c) => c.startsWith('LOGIN') ? hang : basics(c, capabilities: 'IMAP4rev1')!);
    final session = ImapSession(_id, 'ada@example.org', keychain, connect: plainConnector);
    final run = session.run((_) async => 'ran');
    for (var i = 0; i < 100 && logins() == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(logins(), 1);

    await session.close();

    // Without the close the login waits for ImapSession.timeout (2 minutes).
    await expectLater(run.timeout(const Duration(seconds: 10)), throwsA(isA<ImapFailed>()));
  });
}
