// ImapSession.close while a session is logging in (#191): the removal of the Account closes it, the login in flight
// is not kept nor left hanging.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_failure.dart';
import 'package:postino/core/data/imap/imap_session.dart';
import 'package:postino/core/domain/result.dart';

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

  test('a login refused tries once the password another device brought meanwhile, never more (#321)', () async {
    await start((c) {
      if (!c.startsWith('LOGIN')) return basics(c, capabilities: 'IMAP4rev1')!;
      if (c.contains('arrived')) return ['OK LOGIN completed'];
      // The voce from another device arrives while this login is refused.
      unawaited(server.remember(keychain, _id, password: 'arrived'));
      return ['NO [AUTHENTICATIONFAILED] Authentication failed'];
    });
    final session = ImapSession(_id, 'ada@example.org', keychain, connect: plainConnector);
    expect(await session.run((_) async => 'ran'), 'ran');
    expect(logins(), 2);

    await start(
      (c) => c.startsWith('LOGIN')
          ? ['NO [AUTHENTICATIONFAILED] Authentication failed']
          : basics(c, capabilities: 'IMAP4rev1')!,
    );
    final refused = ImapSession(_id, 'ada@example.org', keychain, connect: plainConnector);
    await expectLater(refused.run((_) async => 'ran'), throwsA(isA<ImapFailed>()));
    expect(logins(), 1);
  });

  test('closed while the keychain is read again after a refused login: no second LOGIN (#191, #321)', () async {
    final store = _HeldStore();
    server = await RecordedImapServer.start((c) {
      if (!c.startsWith('LOGIN')) return basics(c, capabilities: 'IMAP4rev1')!;
      unawaited(server.remember(store, _id, password: 'arrived'));
      store.armed = true;
      return ['NO [AUTHENTICATIONFAILED] Authentication failed'];
    });
    addTearDown(server.stop);
    await server.remember(store, _id);
    final session = ImapSession(_id, 'ada@example.org', store, connect: plainConnector);
    final run = session.run((_) async => 'ran');
    await store.reading.future;

    await session.close();
    store.release.complete();

    await expectLater(run, throwsA(isA<ImapFailed>()));
    expect(logins(), 1);
  });

  test('a keychain that fails the read again after a refused login still answers AuthFailure (#321)', () async {
    await start((c) {
      if (!c.startsWith('LOGIN')) return basics(c, capabilities: 'IMAP4rev1')!;
      keychain.failure = Exception('locked');
      return ['NO [AUTHENTICATIONFAILED] Authentication failed'];
    });
    final session = ImapSession(_id, 'ada@example.org', keychain, connect: plainConnector);
    await expectLater(
      session.run((_) async => 'ran'),
      throwsA(isA<ImapFailed>().having((e) => e.failure, 'failure', isA<AuthFailure>())),
    );
  });
}

/// A keychain whose next read, once [armed], signals [reading] and waits for [release].
class _HeldStore() extends FakeSecureStore {
  var armed = false;
  final reading = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> read(String key) async {
    if (armed && !reading.isCompleted) {
      reading.complete();
      await release.future;
    }
    return super.read(key);
  }
}
