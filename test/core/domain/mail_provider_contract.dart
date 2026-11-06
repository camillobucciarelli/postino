// Contract suite of the Provider adapter (ADR 0002): real adapters pass the same cases.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';

/// What the suite needs from an adapter under test, beyond [MailProvider] itself.
abstract class ContractHarness() {
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

class FakeHarness() implements ContractHarness {
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
  void attach(String messageId, String name, List<int> bytes) => fake.attach(messageId, name, bytes);
}

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

Matcher _err<F>() => isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<F>());

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
        await h.provider.applyAction('a', const MarkRead(), expected: false),
        await h.provider.createLabel('Fatture'),
        await h.provider.applyAction('a', const ApplyLabel('Label_12'), expected: false),
      ]) {
        expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<AuthFailure>()));
      }
    });

    test('no network is an OfflineFailure', () async {
      h.goOffline();
      for (final r in [
        await h.provider.initialSync(),
        await h.provider.fetchBody('a'),
        await h.provider.fetchConversation('t-a'),
        await h.provider.applyAction('a', const MarkRead(), expected: false),
        await h.provider.createLabel('Fatture'),
        await h.provider.applyAction('a', const ApplyLabel('Label_12'), expected: false),
      ]) {
        expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<OfflineFailure>()));
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
      h
        ..deliver(msg('a'))
        ..deliver(msg('b'))
        ..deliver(msg('c'));
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

    test('initial sync brings Etichette, Conversazioni and only the inbox bodies', () async {
      h
        ..deliver(msg('a', isRead: true, isStarred: true))
        ..deliver(msg('s', labelIds: const ['SENT']));
      final batch = _ok(await h.provider.initialSync());
      expect(batch.labels!.map((l) => (l.id, l.name)), [('Label_12', 'Viaggi')]);
      final a = batch.messages.singleWhere((m) => m.id == 'a');
      expect(a.conversationId, 't-a');
      expect(a.labelIds, contains(inboxLabelId));
      expect((a.isRead, a.isStarred), (true, true));
      expect(a.messageId, '<a@example.com>');
      expect(a.from, 'ada@example.com');
      expect(a.subject, 'Oggetto');
      expect(a.date, DateTime.utc(2026));
      expect(batch.bodies.keys, ['a']);
    });

    test('the sender name and the Cc come back with the message', () async {
      h.deliver(msg('a', fromName: 'Ada Okafor', cc: const ['Marco Lenti <marco@example.com>', 'carla@example.org']));
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

    test('a message removed remotely shows up as removed and moves the cursor', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h.removeRemotely('a');
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.removedMessageIds, ['a']);
      expect(next.cursor, isNot(first.cursor));
    });

    test('the delta reduces each message to its final state', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h
        ..removeRemotely('a')
        ..deliver(msg('a'))
        ..deliver(msg('b'))
        ..removeRemotely('b');
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.map((m) => m.id), ['a']);
      expect(next.removedMessageIds, ['b']);
    });

    test('an expired cursor is NotFound', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h
        ..deliver(msg('b'))
        ..expireCursors();
      expect(await h.provider.incrementalSync(first.cursor), _err<NotFoundFailure>());
    });

    test('fetches a body on request and NotFound for an unknown message', () async {
      h.deliver(msg('a'));
      expect(_ok(await h.provider.fetchBody('a')).content, isNotEmpty);
      expect(await h.provider.fetchBody('zzz'), _err<NotFoundFailure>());
    });

    test('fetches every message of a Conversazione, Inviati too', () async {
      h
        ..deliver(msg('a', conversationId: 't'))
        ..deliver(msg('b', conversationId: 't', labelIds: const ['SENT']))
        ..deliver(msg('c'));
      final messages = _ok(await h.provider.fetchConversation('t'));
      expect(messages.map((m) => m.id), unorderedEquals(['a', 'b']));
      expect(messages.map((m) => m.conversationId).toSet(), {'t'});
    });

    test('a message marked read comes back read with the next sync', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      _ok(await h.provider.applyAction('a', const MarkRead(), expected: false));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.single.isRead, isTrue);
      _ok(await h.provider.applyAction('a', const MarkRead(), expected: false));
    });
  });
}

OutgoingMessage _draft(String messageId, {String body = '<p>Ciao</p>'}) => OutgoingMessage(
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
      _ok(await h.provider.saveDraft(_draft('<x@example.com>', body: '<p>Seconda</p>'), isNew: false));
      final m = _ok(await h.provider.initialSync()).messages.single;
      expect(m.messageId, '<x@example.com>');
      expect(_ok(await h.provider.fetchBody(m.id)).content.trim(), '<p>Seconda</p>');
    });

    test('updating a Bozza never saved is NotFound', () async {
      expect(await h.provider.saveDraft(_draft('<nope@example.com>'), isNew: false), _err<NotFoundFailure>());
    });

    test('deleting a Bozza twice is NotFound the second time; so is updating it', () async {
      final d = _draft('<x@example.com>');
      _ok(await h.provider.saveDraft(d, isNew: true));
      _ok(await h.provider.deleteDraft(d.messageId));
      expect(await h.provider.deleteDraft(d.messageId), _err<NotFoundFailure>());
      expect(await h.provider.saveDraft(d, isNew: false), _err<NotFoundFailure>());
    });

    test('a Bozza written elsewhere syncs as a DRAFT message with its body', () async {
      h.deliverDraft(
        const OutgoingMessage(
          messageId: '<y@example.com>',
          from: 'me@example.com',
          to: ['b@example.com'],
          bcc: ['dee@example.com'],
          subject: 's',
          body: '<p>Da altrove</p>',
        ),
      );
      final m = _ok(await h.provider.initialSync()).messages.single;
      expect(m.labelIds, ['DRAFT']);
      expect(m.messageId, '<y@example.com>');
      expect(m.bcc, ['dee@example.com']);
      expect(_ok(await h.provider.fetchBody(m.id)).content, '<p>Da altrove</p>');
    });
  });
}

/// Attachments (#34): listed with the body, downloaded one at a time.
void mailProviderAttachmentContract(String name, ContractHarness Function() create) {
  group('MailProvider attachment contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    test('the body lists the attachments, each downloads on its own', () async {
      h
        ..deliver(msg('a'))
        ..attach('a', 'Preventivo.pdf', utf8.encode('%PDF-1.4 preventivo'))
        ..attach('a', 'foto.jpg', [0xFF, 0xD8, 0xFF, 0xE0]);
      final body = _ok(await h.provider.fetchBody('a'));
      expect(body.attachments!.map((a) => (a.name, a.size)), [('Preventivo.pdf', 19), ('foto.jpg', 4)]);

      final progress = <double>[];
      final pdf = _ok(await h.provider.fetchAttachment('a', body.attachments!.first.id, onProgress: progress.add));
      expect(utf8.decode(pdf), '%PDF-1.4 preventivo');
      expect(progress.last, 1);
      expect(_ok(await h.provider.fetchAttachment('a', body.attachments!.last.id)), [0xFF, 0xD8, 0xFF, 0xE0]);
    });

    test('an unknown attachment is NotFound', () async {
      h.deliver(msg('a'));
      final r = await h.provider.fetchAttachment('a', 'nope');
      expect(r, _err<NotFoundFailure>());
    });

    test('offline, a download is OfflineFailure', () async {
      h
        ..deliver(msg('a'))
        ..attach('a', 'a.txt', [1, 2, 3]);
      final id = _ok(await h.provider.fetchBody('a')).attachments!.single.id;
      h.goOffline();
      expect(await h.provider.fetchAttachment('a', id), _err<OfflineFailure>());
    });
  });
}

/// Sending (#36): idempotent on the Message-ID, the sent message lands in Inviati, its Bozza goes.
void mailProviderSendContract(String name, ContractHarness Function() create) {
  group('MailProvider send contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());
    final d = _draft('<x@example.com>');
    final raw = renderMime(d, DateTime.utc(2026));

    test('the sent message arrives with label SENT at the next sync', () async {
      final id = _ok(await h.provider.send(d.messageId, raw));
      final m = _ok(await h.provider.initialSync()).messages.single;
      expect((m.id, m.messageId), (id, d.messageId));
      expect(m.labelIds, [sentLabelId]);
      expect(m.to, ['b@example.com']);
      expect(m.subject, 's');
    });

    test('sending the same Message-ID twice leaves one message in SENT', () async {
      final first = _ok(await h.provider.send(d.messageId, raw));
      expect(_ok(await h.provider.send(d.messageId, raw)), first);
      final sent = _ok(await h.provider.initialSync()).messages.where((m) => m.labelIds.contains(sentLabelId));
      expect(sent.map((m) => m.messageId), [d.messageId]);
    });

    test('the Bozza holding the Message-ID is gone after the send', () async {
      _ok(await h.provider.saveDraft(d, isNew: true));
      _ok(await h.provider.send(d.messageId, raw));
      expect(await h.provider.deleteDraft(d.messageId), _err<NotFoundFailure>());
      final labels = _ok(await h.provider.initialSync()).messages.map((m) => m.labelIds).expand((l) => l);
      expect(labels, [sentLabelId]);
    });

    test('offline is an OfflineFailure', () async {
      h.goOffline();
      expect(await h.provider.send(d.messageId, raw), _err<OfflineFailure>());
    });
  });
}

/// Etichette (#105): created on the Provider, added to and removed from a message; every call idempotent.
void mailProviderLabelContract(String name, ContractHarness Function() create) {
  group('MailProvider label contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    Future<List<String>> labelsOf(String cursor, String id) async =>
        _ok(await h.provider.incrementalSync(cursor)).messages.singleWhere((m) => m.id == id).labelIds;

    test('a created Etichetta comes with the next incremental sync; creating it again returns the same one', () async {
      final first = _ok(await h.provider.initialSync());
      final created = _ok(await h.provider.createLabel('Fatture'));
      expect((created.name, created.kind), ('Fatture', LabelKind.etichetta));
      expect(_ok(await h.provider.createLabel('Fatture')), created);
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(
        next.labels!.map((l) => (l.id, l.name)),
        unorderedEquals([('Label_12', 'Viaggi'), (created.id, 'Fatture')]),
      );
    });

    test('creating an Etichetta that already exists returns it', () async {
      expect(_ok(await h.provider.createLabel('Viaggi')).id, 'Label_12');
    });

    test('an Etichetta added twice is on the message once; removed twice, it is gone', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      _ok(await h.provider.applyAction('a', const ApplyLabel('Label_12'), expected: false));
      _ok(await h.provider.applyAction('a', const ApplyLabel('Label_12'), expected: false));
      final added = await labelsOf(first.cursor, 'a');
      expect(added.where((l) => l == 'Label_12'), hasLength(1));
      expect(added, contains(inboxLabelId));
      _ok(await h.provider.applyAction('a', const RemoveLabel('Label_12'), expected: true));
      _ok(await h.provider.applyAction('a', const RemoveLabel('Label_12'), expected: true));
      expect(await labelsOf(first.cursor, 'a'), isNot(contains('Label_12')));
    });

    test('an Etichetta on a message gone from the Provider is messaggioSparito', () async {
      expect(
        _ok(await h.provider.applyAction('zzz', const ApplyLabel('Label_12'), expected: false)),
        isA<ActionMessageGone>(),
      );
    });
  });
}

/// The conditional Azione (ADR 0008): applied on the expected or the wanted value, a Conflitto on another one.
void mailProviderActionContract(String name, ContractHarness Function() create) {
  group('MailProvider action contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    Future<Message> now(String id) async => _ok(await h.provider.initialSync()).messages.singleWhere((m) => m.id == id);

    test('the expected value: applied', () async {
      h.deliver(msg('a'));
      expect(_ok(await h.provider.applyAction('a', const Star(), expected: false)), isA<ActionApplied>());
      expect((await now('a')).isStarred, isTrue);
    });

    test('the wanted value already, changed elsewhere the same way: applied', () async {
      h.deliver(msg('a', isRead: true));
      expect(_ok(await h.provider.applyAction('a', const MarkRead(), expected: false)), isA<ActionApplied>());
      expect((await now('a')).isRead, isTrue);
    });

    test('another value, changed elsewhere: a Conflitto with it, nothing written', () async {
      h.deliver(msg('a', labelIds: const [trashLabelId]));
      expect(
        _ok(await h.provider.applyAction('a', const Archive(), expected: Placement.inbox)),
        isA<ActionConflict>().having((c) => c.providerValue, 'providerValue', Placement.trash),
      );
      expect((await now('a')).labelIds, allOf(contains(trashLabelId), isNot(contains(inboxLabelId))));
    });

    test('Elimina never conflicts', () async {
      h.deliver(msg('a', labelIds: const []));
      expect(_ok(await h.provider.applyAction('a', const Delete(), expected: Placement.inbox)), isA<ActionApplied>());
      expect((await now('a')).labelIds, allOf(contains(trashLabelId), isNot(contains(inboxLabelId))));
    });

    test('no expected value: forced', () async {
      h.deliver(msg('a', isRead: true));
      expect(_ok(await h.provider.applyAction('a', const MarkUnread())), isA<ActionApplied>());
      expect((await now('a')).isRead, isFalse);
    });

    test('a message gone: messaggioSparito', () async {
      expect(
        _ok(await h.provider.applyAction('zzz', const Delete(), expected: Placement.inbox)),
        isA<ActionMessageGone>(),
      );
    });
  });
}

void mailProviderContract(String name, ContractHarness Function() create) {
  mailProviderAuthContract(name, create);
  mailProviderSyncContract(name, create);
  mailProviderAttachmentContract(name, create);
  mailProviderDraftContract(name, create);
  mailProviderSendContract(name, create);
  mailProviderLabelContract(name, create);
}
