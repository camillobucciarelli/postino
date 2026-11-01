// Contract suite of the Provider adapter (ADR 0002): real adapters pass the same cases.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';

/// What the suite needs from an adapter under test, beyond [MailProvider] itself.
abstract class ContractHarness {
  MailProvider get provider;

  /// A message arrives in the mailbox "elsewhere".
  void deliver(Message m);

  /// A message is deleted from the mailbox "elsewhere".
  void removeRemotely(String id);

  /// The Provider no longer remembers the changes behind any cursor handed out so far.
  void expireCursors();
  void goOffline();
  void breakAuth();

  /// A Bozza is written in the Bozze folder "elsewhere" (another client).
  void deliverDraft(OutgoingMessage d);

  /// Gives message [messageId] an attachment [name] holding [bytes].
  void attach(String messageId, String name, List<int> bytes);
}

class FakeHarness implements ContractHarness {
  final fake = FakeMailProvider();
  @override
  MailProvider get provider => fake;
  @override
  void deliver(Message m) => fake.deliver(m);
  @override
  void removeRemotely(String id) => fake.removeRemotely(id);
  @override
  void expireCursors() => fake.expireCursors();
  @override
  void goOffline() => fake.goOffline();
  @override
  void breakAuth() => fake.breakAuth();
  @override
  void deliverDraft(OutgoingMessage d) => fake.deliverDraft(d);
  @override
  void attach(String messageId, String name, List<int> bytes) =>
      fake.attach(messageId, name, bytes);
}

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

Matcher _err<F>() => isA<Err>().having((e) => e.failure, 'failure', isA<F>());

/// The access part of the contract: what an adapter must honour before it can sync.
void mailProviderAuthContract(String name, ContractHarness Function() create) {
  group('MailProvider auth contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    test('a refused login is an AuthFailure', () async {
      h.breakAuth();
      for (final r in [
        await h.provider.refreshAuth(),
        await h.provider.initialSync(),
        await h.provider.incrementalSync('0'),
        await h.provider.setRead(['a'], read: true),
      ]) {
        expect(
          r,
          isA<Err>().having((e) => e.failure, 'failure', isA<AuthFailure>()),
        );
      }
    });

    test('no network is an OfflineFailure', () async {
      h.goOffline();
      for (final r in [
        await h.provider.initialSync(),
        await h.provider.fetchBody('a'),
        await h.provider.fetchConversation('t-a'),
        await h.provider.setRead(['a'], read: true),
      ]) {
        expect(
          r,
          isA<Err>().having((e) => e.failure, 'failure', isA<OfflineFailure>()),
        );
      }
    });
  });
}

/// The sync part of the contract (ADR 0008): initial sync, incremental sync from the cursor, bodies.
void mailProviderSyncContract(String name, ContractHarness Function() create) {
  group('MailProvider sync contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    test('initial sync returns the mailbox messages and a cursor', () async {
      h.deliver(msg('a'));
      h.deliver(msg('b'));
      h.deliver(msg('c'));
      final batch = _ok(await h.provider.initialSync());
      expect(batch.messages.map((m) => m.id), unorderedEquals(['a', 'b', 'c']));
      expect(batch.cursor, isNotEmpty);
    });

    test('initial sync hands over every message in pages too', () async {
      for (final id in ['a', 'b', 'c']) {
        h.deliver(msg(id));
      }
      final paged = <String>[];
      final batch = _ok(
        await h.provider.initialSync(
          onPage: (messages, bodies) async {
            paged.addAll(messages.map((m) => m.id));
            expect(bodies.keys, everyElement(isIn(paged)));
          },
        ),
      );
      expect(paged, unorderedEquals(batch.messages.map((m) => m.id)));
    });

    test('initial sync of an empty mailbox still returns a cursor', () async {
      final batch = _ok(await h.provider.initialSync());
      expect(batch.messages, isEmpty);
      expect(batch.cursor, isNotEmpty);
    });

    test(
      'initial sync brings Etichette, Conversazioni and only the inbox bodies',
      () async {
        h.deliver(msg('a', isRead: true, isStarred: true));
        h.deliver(msg('s', labelIds: const ['SENT']));
        final batch = _ok(await h.provider.initialSync());
        expect(batch.labels.map((l) => (l.id, l.name)), [
          ('Label_12', 'Viaggi'),
        ]);
        final a = batch.messages.singleWhere((m) => m.id == 'a');
        expect(a.conversationId, 't-a');
        expect(a.labelIds, contains(inboxLabelId));
        expect((a.isRead, a.isStarred), (true, true));
        expect(a.messageId, '<a@example.com>');
        expect(a.from, 'ada@example.com');
        expect(a.subject, 'Oggetto');
        expect(a.date, DateTime.utc(2026, 1, 1));
        expect(batch.bodies.keys, ['a']);
      },
    );

    test('the sender name and the Cc come back with the message', () async {
      h.deliver(
        msg(
          'a',
          from: 'ada@example.com',
          fromName: 'Ada Okafor',
          cc: const ['Marco Lenti <marco@example.com>', 'carla@example.org'],
        ),
      );
      final a = _ok(await h.provider.initialSync()).messages.single;
      expect((a.from, a.fromName), ('ada@example.com', 'Ada Okafor'));
      expect(a.cc, ['Marco Lenti <marco@example.com>', 'carla@example.org']);
    });

    test('incremental sync from a cursor returns only what changed', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h.deliver(msg('b'));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.map((m) => m.id), ['b']);
      expect(next.bodies.keys, ['b']);
      final again = _ok(await h.provider.incrementalSync(next.cursor));
      expect(again.messages, isEmpty);
    });

    test('a message read and starred elsewhere comes back changed', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h.deliver(msg('a', isRead: true, isStarred: true));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      final a = next.messages.single;
      expect((a.id, a.isRead, a.isStarred), ('a', true, true));
    });

    test(
      'a message removed remotely shows up as removed and moves the cursor',
      () async {
        h.deliver(msg('a'));
        final first = _ok(await h.provider.initialSync());
        h.removeRemotely('a');
        final next = _ok(await h.provider.incrementalSync(first.cursor));
        expect(next.removedMessageIds, ['a']);
        expect(next.cursor, isNot(first.cursor));
      },
    );

    test('the delta reduces each message to its final state', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h.removeRemotely('a');
      h.deliver(msg('a'));
      h.deliver(msg('b'));
      h.removeRemotely('b');
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.map((m) => m.id), ['a']);
      expect(next.removedMessageIds, ['b']);
    });

    test('an expired cursor is NotFound', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h.deliver(msg('b'));
      h.expireCursors();
      expect(
        await h.provider.incrementalSync(first.cursor),
        _err<NotFoundFailure>(),
      );
    });

    test(
      'fetches a body on request and NotFound for an unknown message',
      () async {
        h.deliver(msg('a'));
        expect(_ok(await h.provider.fetchBody('a')).content, isNotEmpty);
        expect(await h.provider.fetchBody('zzz'), _err<NotFoundFailure>());
      },
    );

    test('fetches every message of a Conversazione, Inviati too', () async {
      h.deliver(msg('a', conversationId: 't'));
      h.deliver(msg('b', conversationId: 't', labelIds: const ['SENT']));
      h.deliver(msg('c'));
      final messages = _ok(await h.provider.fetchConversation('t'));
      expect(messages.map((m) => m.id), unorderedEquals(['a', 'b']));
      expect(messages.map((m) => m.conversationId).toSet(), {'t'});
    });

    test('a message marked read comes back read with the next sync', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      _ok(await h.provider.setRead(['a'], read: true));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.single.isRead, isTrue);
      _ok(await h.provider.setRead(['a'], read: true));
    });
  });
}

OutgoingMessage _draft(String messageId, {String body = '<p>Ciao</p>'}) =>
    OutgoingMessage(
      messageId: messageId,
      from: 'me@example.com',
      to: const ['b@example.com'],
      subject: 's',
      body: body,
    );

/// The Bozze part of the contract (#35): create, update by Message-ID, delete, and Bozze written elsewhere.
void mailProviderDraftContract(String name, ContractHarness Function() create) {
  group('MailProvider draft contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    test('a saved Bozza can be updated by its Message-ID', () async {
      final d = _draft('<x@example.com>');
      _ok(await h.provider.saveDraft(d, isNew: true));
      _ok(await h.provider.saveDraft(d, isNew: false));
    });

    test('updating a Bozza never saved is NotFound', () async {
      expect(
        await h.provider.saveDraft(_draft('<nope@example.com>'), isNew: false),
        _err<NotFoundFailure>(),
      );
    });

    test(
      'deleting a Bozza twice is NotFound the second time; so is updating it',
      () async {
        final d = _draft('<x@example.com>');
        _ok(await h.provider.saveDraft(d, isNew: true));
        _ok(await h.provider.deleteDraft(d.messageId));
        expect(
          await h.provider.deleteDraft(d.messageId),
          _err<NotFoundFailure>(),
        );
        expect(
          await h.provider.saveDraft(d, isNew: false),
          _err<NotFoundFailure>(),
        );
      },
    );

    test(
      'a Bozza written elsewhere syncs as a DRAFT message with its body',
      () async {
        h.deliverDraft(_draft('<y@example.com>', body: '<p>Da altrove</p>'));
        final m = _ok(await h.provider.initialSync()).messages.single;
        expect(m.labelIds, ['DRAFT']);
        expect(m.messageId, '<y@example.com>');
        expect(
          _ok(await h.provider.fetchBody(m.id)).content,
          '<p>Da altrove</p>',
        );
      },
    );
  });
}

/// Attachments (#34): listed with the body, downloaded one at a time.
void mailProviderAttachmentContract(
  String name,
  ContractHarness Function() create,
) {
  group('MailProvider attachment contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    test('the body lists the attachments, each downloads on its own', () async {
      h.deliver(msg('a'));
      h.attach('a', 'Preventivo.pdf', utf8.encode('%PDF-1.4 preventivo'));
      h.attach('a', 'foto.jpg', [0xFF, 0xD8, 0xFF, 0xE0]);
      final body = _ok(await h.provider.fetchBody('a'));
      expect(body.attachments!.map((a) => (a.name, a.size)), [
        ('Preventivo.pdf', 19),
        ('foto.jpg', 4),
      ]);

      final progress = <double>[];
      final pdf = _ok(
        await h.provider.fetchAttachment(
          'a',
          body.attachments!.first.id,
          onProgress: progress.add,
        ),
      );
      expect(utf8.decode(pdf), '%PDF-1.4 preventivo');
      expect(progress.last, 1);
      expect(
        _ok(await h.provider.fetchAttachment('a', body.attachments!.last.id)),
        [0xFF, 0xD8, 0xFF, 0xE0],
      );
    });

    test('an unknown attachment is NotFound', () async {
      h.deliver(msg('a'));
      final r = await h.provider.fetchAttachment('a', 'nope');
      expect(r, _err<NotFoundFailure>());
    });

    test('offline, a download is OfflineFailure', () async {
      h.deliver(msg('a'));
      h.attach('a', 'a.txt', [1, 2, 3]);
      final id = _ok(await h.provider.fetchBody('a')).attachments!.single.id;
      h.goOffline();
      expect(await h.provider.fetchAttachment('a', id), _err<OfflineFailure>());
    });
  });
}

void mailProviderContract(String name, ContractHarness Function() create) {
  mailProviderAuthContract(name, create);
  mailProviderSyncContract(name, create);
  mailProviderAttachmentContract(name, create);
  mailProviderDraftContract(name, create);
  group('MailProvider contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    test('send is accepted', () async {
      _ok(await h.provider.send(_draft('<x@example.com>')));
    });
  });
}
