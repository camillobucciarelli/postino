// Contract suite of the Provider adapter (ADR 0002): real adapters pass the same cases.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';

/// What the suite needs from an adapter under test, beyond [MailProvider] itself. The changes "elsewhere" may be
/// asynchronous (a real server): the suite awaits them.
abstract class ContractHarness() {
  MailProvider get provider;

  /// A message arrives in the mailbox "elsewhere"; delivered again (same id), it changes there: its flags, its folder.
  FutureOr<void> deliver(Message m);

  /// A message is deleted from the mailbox "elsewhere".
  FutureOr<void> removeRemotely(String id);

  /// The Provider no longer remembers the changes behind any cursor handed out so far.
  FutureOr<void> expireCursors();
  FutureOr<void> goOffline();
  FutureOr<void> breakAuth();

  /// A Bozza is written in the Bozze folder "elsewhere" (another client).
  FutureOr<void> deliverDraft(OutgoingMessage d);

  /// Gives message [messageId] an attachment [name] holding [bytes].
  FutureOr<void> attach(String messageId, String name, List<int> bytes);

  /// The Provider id of the message delivered as `msg(key)`, where it was last delivered: the adapter may name it
  /// otherwise (IMAP: `cartella/UIDVALIDITY/UID`).
  String idOf(String key) => key;

  /// The Conversazione the adapter gives `msg(key)` delivered on its own.
  String conversationOf(String key) => 't-$key';

  /// The id of the Etichetta `Viaggi` every mailbox starts with, and the kind of a created one.
  String get viaggiId => 'Label_12';
  LabelKind get createdKind => LabelKind.etichetta;

  /// Whether an expired cursor rebuilds what it covered (IMAP: a new UIDVALIDITY drops the old ids and fetches the
  /// folder again) instead of being [NotFoundFailure].
  bool get rebuildsExpiredCursor => false;

  /// Whether an Etichetta is a folder: applying it moves the message out of the inbox, and its Provider id changes.
  bool get labelsAreFolders => false;

  /// Releases the adapter's connections after a test.
  Future<void> dispose() async {}
}

class FakeHarness() extends ContractHarness {
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

/// Builds the harness of one test.
typedef CreateHarness = FutureOr<ContractHarness> Function();

/// The capabilities an adapter does not have yet, by the ticket bringing them: their cases are skipped.
/// Keys: `body` (fetchBody), `conversation` (fetchConversation), `action` (applyAction).
typedef Pending = Map<String, String>;

void _harness(CreateHarness create, void Function(ContractHarness h) got) {
  late ContractHarness h;
  setUp(() async => got(h = await create()));
  tearDown(() => h.dispose());
}

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

Matcher _err<F>() => isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<F>());

/// The access part of the contract: what an adapter must honour before it can sync.
void mailProviderAuthContract(String name, CreateHarness create, {Pending pending = const {}}) {
  group('MailProvider auth contract: $name', () {
    late ContractHarness h;
    _harness(create, (x) => h = x);
    final actions = !pending.containsKey('action');

    test('a refused login is an AuthFailure', () async {
      await h.breakAuth();
      for (final r in [
        await h.provider.refreshAuth(),
        await h.provider.initialSync(),
        await h.provider.incrementalSync('0'),
        if (actions) await h.provider.applyAction(h.idOf('a'), const MarkRead(), expected: false),
        await h.provider.createLabel('Fatture'),
        if (actions) await h.provider.applyAction(h.idOf('a'), ApplyLabel(h.viaggiId), expected: false),
      ]) {
        expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<AuthFailure>()));
      }
    });

    test('no network is an OfflineFailure', () async {
      await h.goOffline();
      for (final r in [
        await h.provider.initialSync(),
        if (!pending.containsKey('body')) await h.provider.fetchBody(h.idOf('a')),
        if (!pending.containsKey('conversation')) await h.provider.fetchConversation(h.conversationOf('a')),
        if (actions) await h.provider.applyAction(h.idOf('a'), const MarkRead(), expected: false),
        await h.provider.createLabel('Fatture'),
        if (actions) await h.provider.applyAction(h.idOf('a'), ApplyLabel(h.viaggiId), expected: false),
      ]) {
        expect(r, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<OfflineFailure>()));
      }
    });
  });
}

/// The sync part of the contract (ADR 0008): initial sync, incremental sync from the cursor, bodies.
void mailProviderSyncContract(String name, CreateHarness create, {Pending pending = const {}}) {
  group('MailProvider sync contract: $name', () {
    late ContractHarness h;
    _harness(create, (x) => h = x);

    test('initial sync returns the mailbox messages and a cursor', () async {
      await h.deliver(msg('a'));
      await h.deliver(msg('b'));
      await h.deliver(msg('c'));
      final batch = _ok(await h.provider.initialSync());
      expect(batch.messages.map((m) => m.id), unorderedEquals(['a', 'b', 'c'].map(h.idOf)));
      expect(batch.cursor, isNotEmpty);
    });

    test('initial sync hands over every message in pages too', () async {
      for (final id in ['a', 'b', 'c']) {
        await h.deliver(msg(id));
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
      await h.deliver(msg('a', isRead: true, isStarred: true));
      await h.deliver(msg('s', labelIds: const ['SENT']));
      final batch = _ok(await h.provider.initialSync());
      expect(batch.labels!.map((l) => (l.id, l.name)), [(h.viaggiId, 'Viaggi')]);
      final a = batch.messages.singleWhere((m) => m.id == h.idOf('a'));
      expect(a.conversationId, h.conversationOf('a'));
      expect(a.labelIds, contains(inboxLabelId));
      expect((a.isRead, a.isStarred), (true, true));
      expect(a.messageId, '<a@example.com>');
      expect(a.from, 'ada@example.com');
      expect(a.subject, 'Oggetto');
      expect(a.date, DateTime.utc(2026));
      expect(batch.bodies.keys, [h.idOf('a')]);
    });

    test('the sender name and the Cc come back with the message', () async {
      await h.deliver(
        msg('a', fromName: 'Ada Okafor', cc: const ['Marco Lenti <marco@example.com>', 'carla@example.org']),
      );
      final a = _ok(await h.provider.initialSync()).messages.single;
      expect((a.from, a.fromName), ('ada@example.com', 'Ada Okafor'));
      expect(a.cc, ['Marco Lenti <marco@example.com>', 'carla@example.org']);
    });

    test('incremental sync from a cursor returns only what changed', () async {
      await h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      await h.deliver(msg('b'));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.map((m) => m.id), [h.idOf('b')]);
      expect(next.bodies.keys, [h.idOf('b')]);
      final again = _ok(await h.provider.incrementalSync(next.cursor));
      expect(again.messages, isEmpty);
    });

    test('a message read and starred elsewhere comes back changed', () async {
      await h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      await h.deliver(msg('a', isRead: true, isStarred: true));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      final a = next.messages.single;
      expect((a.id, a.isRead, a.isStarred), (h.idOf('a'), true, true));
    });

    test('a message removed remotely shows up as removed and moves the cursor', () async {
      await h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      await h.removeRemotely('a');
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.removedMessageIds, [h.idOf('a')]);
      expect(next.cursor, isNot(first.cursor));
    });

    test('the delta reduces each message to its final state', () async {
      await h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      final before = h.idOf('a');
      await h.removeRemotely('a');
      await h.deliver(msg('a'));
      await h.deliver(msg('b'));
      final b = h.idOf('b');
      await h.removeRemotely('b');
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.map((m) => m.id), [h.idOf('a')]);
      // Delivered again, `a` may have a new id (IMAP: a new UID): only the old one may go, with `b`.
      expect(next.removedMessageIds, isNot(contains(h.idOf('a'))));
      expect(next.removedMessageIds.toSet().difference({b, before}), isEmpty);
      if (before == h.idOf('a')) expect(next.removedMessageIds, [b]);
    });

    test('an expired cursor is NotFound, or rebuilds what it covered', () async {
      await h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      final a = h.idOf('a');
      await h.deliver(msg('b'));
      await h.expireCursors();
      final next = await h.provider.incrementalSync(first.cursor);
      if (!h.rebuildsExpiredCursor) return expect(next, _err<NotFoundFailure>());
      // The mailbox starts over empty: whatever the cursor knew goes, nothing stays twice.
      expect(_ok(next).removedMessageIds, contains(a));
      expect(_ok(next).messages, isEmpty);
    });

    test('fetches a body on request and NotFound for an unknown message', () async {
      await h.deliver(msg('a'));
      expect(_ok(await h.provider.fetchBody(h.idOf('a'))).content, isNotEmpty);
      expect(await h.provider.fetchBody('zzz'), _err<NotFoundFailure>());
    }, skip: pending['body']);

    test('fetches every message of a Conversazione, Inviati too', () async {
      final t = h.conversationOf('a');
      await h.deliver(msg('a', conversationId: t));
      await h.deliver(msg('b', conversationId: t, labelIds: const ['SENT'], references: const ['<a@example.com>']));
      await h.deliver(msg('c'));
      final messages = _ok(await h.provider.fetchConversation(t));
      expect(messages.map((m) => m.id), unorderedEquals(['a', 'b'].map(h.idOf)));
      expect(messages.map((m) => m.conversationId).toSet(), {t});
    }, skip: pending['conversation']);

    test('a message marked read comes back read with the next sync', () async {
      await h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      _ok(await h.provider.applyAction(h.idOf('a'), const MarkRead(), expected: false));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.single.isRead, isTrue);
      _ok(await h.provider.applyAction(h.idOf('a'), const MarkRead(), expected: false));
    }, skip: pending['action']);
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
/// Without `body` the bodies are not checked.
void mailProviderDraftContract(String name, CreateHarness create, {Pending pending = const {}}) {
  group('MailProvider draft contract: $name', () {
    late ContractHarness h;
    _harness(create, (x) => h = x);

    test('a saved Bozza can be updated by its Message-ID', () async {
      final d = _draft('<x@example.com>');
      _ok(await h.provider.saveDraft(d, isNew: true));
      _ok(await h.provider.saveDraft(_draft('<x@example.com>', body: '<p>Seconda</p>'), isNew: false));
      final m = _ok(await h.provider.initialSync()).messages.single;
      expect(m.messageId, '<x@example.com>');
      if (!pending.containsKey('body')) {
        expect(_ok(await h.provider.fetchBody(m.id)).content.trim(), '<p>Seconda</p>');
      }
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
      await h.deliverDraft(
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
      if (!pending.containsKey('body')) {
        expect(_ok(await h.provider.fetchBody(m.id)).content, '<p>Da altrove</p>');
      }
    });
  });
}

/// Attachments (#34): listed with the body, downloaded one at a time.
void mailProviderAttachmentContract(String name, CreateHarness create) {
  group('MailProvider attachment contract: $name', () {
    late ContractHarness h;
    _harness(create, (x) => h = x);

    test('the body lists the attachments, each downloads on its own', () async {
      await h.deliver(msg('a'));
      await h.attach('a', 'Preventivo.pdf', utf8.encode('%PDF-1.4 preventivo'));
      await h.attach('a', 'foto.jpg', [0xFF, 0xD8, 0xFF, 0xE0]);
      final a = h.idOf('a');
      final body = _ok(await h.provider.fetchBody(a));
      expect(body.attachments!.map((a) => a.name), ['Preventivo.pdf', 'foto.jpg']);
      expect(body.attachments!.map((a) => a.size), [19, 4]);

      final progress = <double>[];
      final pdf = _ok(await h.provider.fetchAttachment(a, body.attachments!.first.id, onProgress: progress.add));
      expect(utf8.decode(pdf), '%PDF-1.4 preventivo');
      expect(progress.last, 1);
      expect(_ok(await h.provider.fetchAttachment(a, body.attachments!.last.id)), [0xFF, 0xD8, 0xFF, 0xE0]);
    });

    test('an unknown attachment is NotFound', () async {
      await h.deliver(msg('a'));
      final r = await h.provider.fetchAttachment(h.idOf('a'), 'nope');
      expect(r, _err<NotFoundFailure>());
    });

    test('offline, a download is OfflineFailure', () async {
      await h.deliver(msg('a'));
      await h.attach('a', 'a.txt', [1, 2, 3]);
      final id = _ok(await h.provider.fetchBody(h.idOf('a'))).attachments!.single.id;
      await h.goOffline();
      expect(await h.provider.fetchAttachment(h.idOf('a'), id), _err<OfflineFailure>());
    });
  });
}

/// Sending (#36): idempotent on the Message-ID, the sent message lands in Inviati, its Bozza goes.
void mailProviderSendContract(String name, CreateHarness create) {
  group('MailProvider send contract: $name', () {
    late ContractHarness h;
    _harness(create, (x) => h = x);
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
      await h.goOffline();
      expect(await h.provider.send(d.messageId, raw), _err<OfflineFailure>());
    });
  });
}

/// Etichette (#105): created on the Provider, added to and removed from a message; every call idempotent.
void mailProviderLabelContract(String name, CreateHarness create, {Pending pending = const {}}) {
  group('MailProvider label contract: $name', () {
    late ContractHarness h;
    _harness(create, (x) => h = x);

    // By Message-ID: an Etichetta that is a folder moves the message, and its id changes.
    Future<List<String>> labelsOf(String cursor, String key) async =>
        _ok(await h.provider.incrementalSync(cursor)).messages
            .singleWhere((m) => m.messageId == '<$key@example.com>')
            .labelIds;

    test('a created Etichetta comes with the next incremental sync; creating it again returns the same one', () async {
      final first = _ok(await h.provider.initialSync());
      final created = _ok(await h.provider.createLabel('Fatture'));
      expect((created.name, created.kind), ('Fatture', h.createdKind));
      expect(_ok(await h.provider.createLabel('Fatture')), created);
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(
        next.labels!.map((l) => (l.id, l.name)),
        unorderedEquals([(h.viaggiId, 'Viaggi'), (created.id, 'Fatture')]),
      );
    });

    test('creating an Etichetta that already exists returns it', () async {
      expect(_ok(await h.provider.createLabel('Viaggi')).id, h.viaggiId);
    });

    test('an Etichetta added twice is on the message once; removed twice, it is gone', () async {
      await h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      _ok(await h.provider.applyAction(h.idOf('a'), ApplyLabel(h.viaggiId), expected: false));
      _ok(await h.provider.applyAction(h.idOf('a'), ApplyLabel(h.viaggiId), expected: false));
      final added = await labelsOf(first.cursor, 'a');
      expect(added.where((l) => l == h.viaggiId), hasLength(1));
      expect(added, h.labelsAreFolders ? isNot(contains(inboxLabelId)) : contains(inboxLabelId));
      _ok(await h.provider.applyAction(h.idOf('a'), RemoveLabel(h.viaggiId), expected: true));
      _ok(await h.provider.applyAction(h.idOf('a'), RemoveLabel(h.viaggiId), expected: true));
      expect(await labelsOf(first.cursor, 'a'), isNot(contains(h.viaggiId)));
    }, skip: pending['action']);

    test('an Etichetta on a message gone from the Provider is messaggioSparito', () async {
      expect(
        _ok(await h.provider.applyAction(h.idOf('zzz'), ApplyLabel(h.viaggiId), expected: false)),
        isA<ActionMessageGone>(),
      );
    }, skip: pending['action']);
  });
}

/// The conditional Azione (ADR 0008): applied on the expected or the wanted value, a Conflitto on another one.
void mailProviderActionContract(String name, CreateHarness create) {
  group('MailProvider action contract: $name', () {
    late ContractHarness h;
    _harness(create, (x) => h = x);

    // By Message-ID: Archivia and Elimina may move the message, and its id changes.
    Future<Message> now(String key) async =>
        _ok(await h.provider.initialSync()).messages.singleWhere((m) => m.messageId == '<$key@example.com>');

    test('the expected value: applied', () async {
      await h.deliver(msg('a'));
      expect(_ok(await h.provider.applyAction(h.idOf('a'), const Star(), expected: false)), isA<ActionApplied>());
      expect((await now('a')).isStarred, isTrue);
    });

    test('the wanted value already, changed elsewhere the same way: applied', () async {
      await h.deliver(msg('a', isRead: true));
      expect(_ok(await h.provider.applyAction(h.idOf('a'), const MarkRead(), expected: false)), isA<ActionApplied>());
      expect((await now('a')).isRead, isTrue);
    });

    test('another value, changed elsewhere: a Conflitto with it, nothing written', () async {
      await h.deliver(msg('a', labelIds: const [trashLabelId]));
      expect(
        _ok(await h.provider.applyAction(h.idOf('a'), const Archive(), expected: Placement.inbox)),
        isA<ActionConflict>().having((c) => c.providerValue, 'providerValue', Placement.trash),
      );
      expect((await now('a')).labelIds, allOf(contains(trashLabelId), isNot(contains(inboxLabelId))));
    });

    test('Elimina never conflicts', () async {
      await h.deliver(msg('a', labelIds: const []));
      expect(
        _ok(await h.provider.applyAction(h.idOf('a'), const Delete(), expected: Placement.inbox)),
        isA<ActionApplied>(),
      );
      expect((await now('a')).labelIds, allOf(contains(trashLabelId), isNot(contains(inboxLabelId))));
    });

    test('no expected value: forced', () async {
      await h.deliver(msg('a', isRead: true));
      expect(_ok(await h.provider.applyAction(h.idOf('a'), const MarkUnread())), isA<ActionApplied>());
      expect((await now('a')).isRead, isFalse);
    });

    test('a message gone: messaggioSparito', () async {
      expect(
        _ok(await h.provider.applyAction(h.idOf('zzz'), const Delete(), expected: Placement.inbox)),
        isA<ActionMessageGone>(),
      );
    });
  });
}

void mailProviderContract(String name, CreateHarness create) {
  mailProviderAuthContract(name, create);
  mailProviderSyncContract(name, create);
  mailProviderAttachmentContract(name, create);
  mailProviderDraftContract(name, create);
  mailProviderSendContract(name, create);
  mailProviderLabelContract(name, create);
}
