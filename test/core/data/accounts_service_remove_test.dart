// Rimozione di un Account (#174): sync stopped, local data and keychain cleared, Gmail token revoked best effort.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/attachment_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/core/domain/settings_sync_account_use_case.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _ada = 'gmail:ada@gmail.com';

void main() {
  late Harness h;
  late AccountsRepository accounts;
  late FakeMailProvider provider;
  setUp(() async {
    h = await Harness.create();
    accounts = getIt<AccountsRepository>();
    provider = h.providerFor(_ada);
    await accounts.connectGmail();
    await getIt<MailSync>().syncAll();
  });

  test('a removed Gmail Account is gone for good: no row, no keychain entry, no further sync', () async {
    final bob = await h.addAccount('gmail:bob@gmail.com');
    provider.deliver(msg('m1'), signal: false);
    await getIt<MailSync>().syncAll();
    final syncs = provider.syncCalls;

    await accounts.remove(_ada);

    expect((await getIt<MailStore>().accounts()).map((a) => a.id), ['gmail:bob@gmail.com']);
    expect(await h.keychain.read('oauth:$_ada'), isNull);
    expect(await h.keychain.read('password:$_ada'), isNull);
    expect(getIt.isRegistered<MailProvider>(instanceName: _ada), isFalse, reason: 'its adapter is dropped');
    // A restart reads the same database: the Account is not there and does not sync.
    getIt<SyncEngine>().start();
    await getIt<MailSync>().syncAll();
    expect(provider.syncCalls, syncs);
    expect(bob.syncCalls, greaterThan(0), reason: 'the other Account still syncs');
    await getIt<SyncEngine>().stop();
  });

  test('a sync running when the removal starts writes nothing of the Account afterwards', () async {
    provider
      ..deliver(msg('m1'), signal: false)
      ..hold = Completer<void>();
    final syncing = getIt<MailSync>().syncAll();
    final removing = accounts.remove(_ada);
    await pumpEventQueue();
    provider.hold!.complete();
    await Future.wait([syncing, removing]);

    final db = getIt<PostinoDatabase>();
    final left = await db.customSelect('SELECT count(*) AS n FROM messages').getSingle();
    expect(left.read<int>('n'), 0);
  });

  test('a sync queued behind the removal neither reaches the Provider nor writes anything', () async {
    provider
      ..deliver(msg('m1'), signal: false)
      ..hold = Completer<void>();
    final running = getIt<MailSync>().syncAll();
    await pumpEventQueue();
    final removing = accounts.remove(_ada);
    await pumpEventQueue();
    // Read the Accounts before the delete ran: this sync waits in the queue behind it.
    final queued = getIt<MailSync>().syncAll();
    await pumpEventQueue();
    final calls = provider.syncCalls;
    provider.hold!.complete();
    await Future.wait([running, removing, queued]);

    expect(provider.syncCalls, calls);
    final left = await getIt<PostinoDatabase>().customSelect('SELECT count(*) AS n FROM messages').getSingle();
    expect(left.read<int>('n'), 0);
  });

  test('the Azioni queued when the removal is confirmed are never sent', () async {
    provider.deliver(msg('m1'), signal: false);
    await getIt<MailSync>().syncAll();
    provider.hold = Completer<void>();
    final running = getIt<MailSync>().syncAll();
    await pumpEventQueue();
    // Its replay waits in the queue behind the running sync.
    final acting = getIt<MailSync>().act(_ada, ['m1'], const MarkRead());
    await pumpEventQueue();
    final removing = accounts.remove(_ada);
    await pumpEventQueue();
    provider.hold!.complete();
    await Future.wait([running, acting, removing]);

    expect(provider.readCalls, isEmpty);
  });

  test('a Bozza upload in flight when the removal starts deletes nothing on the Provider', () async {
    final sync = getIt<MailSync>();
    for (final id in ['<d1@x>', '<d2@x>']) {
      await sync.saveDraft(
        _ada,
        OutgoingMessage(messageId: id, from: 'ada@gmail.com', to: const ['b@example.com'], subject: 's', body: 'b'),
      );
    }
    provider.holdDraft = Completer<void>();
    final flushing = sync.flushDrafts(_ada);
    await pumpEventQueue();
    expect(provider.draftHeld, isNotNull, reason: 'one upload is in flight');
    final removing = accounts.remove(_ada);
    await pumpEventQueue();
    provider.holdDraft!.complete();
    await Future.wait([flushing, removing]);

    expect(provider.drafts.keys, [provider.draftHeld], reason: 'the uploaded Bozza stays, the next one never goes');
  });

  Future<int> count(String table) async =>
      (await getIt<PostinoDatabase>().customSelect('SELECT count(*) AS n FROM $table').getSingle()).read<int>('n');

  test('a body or a remote Bozza downloaded after the removal is not written', () async {
    final sync = getIt<MailSync>();
    provider
      ..deliver(msg('m1'), signal: false)
      ..deliverDraft(
        const OutgoingMessage(
          messageId: '<r@x>',
          from: 'ada@gmail.com',
          to: ['b@example.com'],
          subject: 's',
          body: 'b',
        ),
        date: DateTime.utc(2030),
      );
    await sync.syncAll();
    // The bodies are to download again.
    await getIt<PostinoDatabase>().customStatement('DELETE FROM bodies');
    provider.holdBody = Completer<void>();
    final opening = sync.openDraft(_ada, '<r@x>');
    final body = sync.fetchBody(_ada, 'm1');
    await pumpEventQueue();

    await accounts.remove(_ada);
    provider.holdBody!.complete();
    await Future.wait([opening, body]);

    for (final table in ['bodies', 'drafts']) {
      expect(await count(table), 0, reason: table);
    }
  });

  test('a Conversazione opened while the removal waits in the queue writes nothing', () async {
    final sync = getIt<MailSync>();
    provider
      ..deliver(msg('m1'), signal: false)
      ..hold = Completer<void>();
    final running = sync.syncAll();
    await pumpEventQueue();
    final removing = accounts.remove(_ada);
    await pumpEventQueue();
    // The Account is still listed: the opening queues behind the delete.
    final opening = sync.openConversation(_ada, 't-m1');
    final completing = sync.completeConversation(_ada, 't-m1');
    await pumpEventQueue();
    provider.hold!.complete();
    await Future.wait([running, removing, opening, completing]);

    for (final table in ['messages', 'message_labels', 'intents']) {
      expect(await count(table), 0, reason: table);
    }
  });

  test('an Etichetta created while the removal waits in the queue is not created on the Provider', () async {
    provider.hold = Completer<void>();
    final running = getIt<MailSync>().syncAll();
    await pumpEventQueue();
    final removing = accounts.remove(_ada);
    await pumpEventQueue();
    final creating = getIt<MailSync>().createLabel(_ada, 'Lavoro');
    await pumpEventQueue();
    provider.hold!.complete();
    await Future.wait([running, removing]);

    expect(await creating, isA<Err<Object>>());
    expect(provider.labels.map((l) => l.name), isNot(contains('Lavoro')));
  });

  test('connecting the same Account again while its removal still runs keeps the new credentials', () async {
    h.httpHold = Completer<void>();
    final removing = accounts.remove(_ada);
    while (h.httpRequests.isEmpty) {
      await pumpEventQueue();
    }
    h.providerFor(_ada);
    final connecting = accounts.connectGmail();
    await pumpEventQueue();
    h.httpHold!.complete();
    await Future.wait([removing, connecting]);

    expect(await h.keychain.read('oauth:$_ada'), contains('refresh-token-2'));
  });

  test('two «Rimuovi» of the same Account make one removal: a later connection keeps its credentials', () async {
    provider.hold = Completer<void>();
    final running = getIt<MailSync>().syncAll();
    await pumpEventQueue();
    h.httpHold = Completer<void>();
    final first = accounts.remove(_ada);
    final second = accounts.remove(_ada);
    expect(identical(first, second), isTrue);
    provider.hold!.complete();
    while (h.httpRequests.isEmpty) {
      await pumpEventQueue();
    }
    // The revocation is still out: a connection now waits for the removal to end.
    h.providerFor(_ada);
    final connecting = accounts.connectGmail();
    await pumpEventQueue();
    h.httpHold!.complete();
    await Future.wait([running, first, second, connecting]);

    expect(h.httpRequests, hasLength(1), reason: 'one revocation');
    expect(await h.keychain.read('oauth:$_ada'), contains('refresh-token-2'));
  });

  test('a Drive consent that ends after the removal writes no tokens and chooses nothing', () async {
    final page = Completer<void>();
    h.consent.gate = page.future;
    final choosing = getIt<SettingsSyncAccountUseCase>().choose(_ada);
    await pumpEventQueue();

    await accounts.remove(_ada);
    page.complete();

    expect(await choosing, isA<Err<void>>());
    expect(await h.keychain.read('oauth:$_ada'), isNull);
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), isNull);
  });

  test('the attachment cache and its copies are emptied; a download still running is not cached', () async {
    final files = getIt<AttachmentRepository>();
    provider.deliver(msg('m1'), signal: false);
    final a = provider.attach('m1', 'a.pdf', [1, 2, 3]);
    final b = provider.attach('m1', 'b.pdf', [4, 5, 6]);
    await getIt<MailSync>().syncAll();
    expect(await files.file(_ada, 'm1', a), isA<Ok<String>>());
    provider.holdAttachment = Completer<void>();
    final downloading = files.file(_ada, 'm1', b);
    await pumpEventQueue();

    await accounts.remove(_ada);
    provider.holdAttachment!.complete();

    expect(await downloading, isA<Err<String>>());
    for (final dir in ['/support/attachments', '/tmp/postino-attachments']) {
      expect(h.fs.directory(dir).listSync(), isEmpty, reason: dir);
    }
  });

  test('a password connection closed while a removal of the same Account ends writes nothing', () async {
    const id = 'icloud:ada@icloud.com';
    h.providerFor(id);
    await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    final gate = Completer<void>();
    h.keychain.deleteGate = gate.future;
    final removing = accounts.remove(id);
    // The row is gone, the keychain cleanup waits: a connection now waits for it.
    while ((await getIt<MailStore>().accounts()).any((a) => a.id == id)) {
      await pumpEventQueue();
    }
    final closed = Completer<void>();
    final connecting = accounts.connectWithPassword('ada@icloud.com', 'app-password-1', cancel: closed.future);
    await pumpEventQueue();
    closed.complete();
    await pumpEventQueue();
    gate.complete();
    await removing;

    expect(await connecting, isA<Err<Account>>().having((e) => e.failure, 'failure', isA<CancelledFailure>()));
    expect(await h.keychain.read('password:$id'), isNull);
    expect((await getIt<MailStore>().accounts()).map((a) => a.id), isNot(contains(id)));
  });

  test('a failed revocation or a keychain that refuses never stops the removal', () async {
    h
      ..httpFailure = Exception('no network')
      ..keychain.failure = Exception('locked');

    await accounts.remove(_ada);

    expect(await getIt<MailStore>().accounts(), isEmpty);
    h.keychain
      ..failure = null
      ..deleteFailure = Exception('denied');
    await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    final settings = getIt<SettingsRepository>();
    await settings.setSettingsSyncAccount('icloud:ada@icloud.com');

    await accounts.remove('icloud:ada@icloud.com');

    expect(await getIt<MailStore>().accounts(), isEmpty);
    expect(await settings.settingsSyncAccount(), isNull);
  });

  test('online, the refresh token is revoked at Google', () async {
    await accounts.remove(_ada);

    final r = h.httpRequests.single;
    expect(r.url, Uri.parse('https://oauth2.googleapis.com/revoke'));
    expect(r.bodyFields, {'token': 'refresh-token-1'});
  });

  test('offline, nothing is sent and the Account is removed anyway', () async {
    h.connectivity.online = false;

    await accounts.remove(_ada);

    expect(h.httpRequests, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
    expect(await h.keychain.read('oauth:$_ada'), isNull);
  });

  test('the Impostazioni di Postino stop syncing on the removed Account', () async {
    final settings = getIt<SettingsRepository>();
    await settings.setSettingsSyncAccount(_ada);

    await accounts.remove(_ada);

    expect(await settings.settingsSyncAccount(), isNull);
  });

  test('an IMAP Account loses its password in the keychain; no revocation', () async {
    await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    expect(await h.keychain.read('password:icloud:ada@icloud.com'), isNotNull);

    await accounts.remove('icloud:ada@icloud.com');

    expect(await h.keychain.read('password:icloud:ada@icloud.com'), isNull);
    expect(h.httpRequests, isEmpty);
  });

  test('a new Account after a removal takes the position after the last one', () async {
    await h.addAccount('gmail:bob@gmail.com');
    await accounts.remove(_ada);
    h
      ..providerFor('gmail:carl@gmail.com')
      ..consent.address = 'carl@gmail.com';

    await accounts.connectGmail();

    final positions = [for (final a in await getIt<MailStore>().accounts()) a.position];
    expect(positions.toSet(), hasLength(2));
  });
}
