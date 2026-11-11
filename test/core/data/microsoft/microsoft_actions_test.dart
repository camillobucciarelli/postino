// The Azioni on a simulated Graph mailbox, beyond the contract: etag preconditions, moves, nothing written when
// there is nothing to write. No network.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_harness.dart';

const _viaggi = 'f-viaggi';

Iterable<String> _writes(GraphHarness h) =>
    h.requests.where((r) => r.method != 'GET' && r.url.host != 'login.microsoftonline.com').map((r) => r.method);

void main() {
  test('a 412 on If-Match for another attribute is no Conflitto: read again, the Azione applies', () async {
    final h = GraphHarness()..deliver(msg('a'));
    var starred = false;
    // The Stella lands between the read and the write of «Segna come letto».
    h.onRequest = (r) {
      if (!starred && r.method == 'PATCH') {
        starred = true;
        h.deliver(msg('a', isStarred: true));
      }
    };
    final outcome = okValue(await h.provider.applyAction('a', const MarkRead(), expected: false));
    expect(outcome, isA<ActionApplied>());
    final now = await h.current('a');
    expect(now.isRead, isTrue);
    expect(now.isStarred, isTrue, reason: 'the other client\'s Stella is kept');
    final patches = h.requests.where((r) => r.method == 'PATCH').toList();
    expect(patches, hasLength(2), reason: 'the first refused with 412, the second after the new read');
    expect(patches.last.headers['if-match'], isNot(patches.first.headers['if-match']));
  });

  test('moved to another folder while «Segna come letto» was queued: it applies in the new folder', () async {
    final h = GraphHarness()..deliver(msg('a', labelIds: [_viaggi]));
    expect(okValue(await h.provider.applyAction('a', const MarkRead(), expected: false)), isA<ActionApplied>());
    final now = await h.current('a');
    expect(now.isRead, isTrue);
    expect(now.labelIds, [_viaggi]);
  });

  test('Archivia of a message that is in the Cestino elsewhere is a Conflitto on the placement', () async {
    final h = GraphHarness()..deliver(msg('a', labelIds: const [trashLabelId]));
    expect(
      okValue(await h.provider.applyAction('a', const Archive(), expected: Placement.inbox)),
      isA<ActionConflict>().having((c) => c.providerValue, 'providerValue', Placement.trash),
    );
    expect(_writes(h), isEmpty);
  });

  test('Elimina moves into Posta eliminata, never conflicts and never sends a DELETE', () async {
    final h = GraphHarness()
      ..deliver(msg('a', labelIds: [_viaggi]))
      ..deliver(msg('b'));
    expect(okValue(await h.provider.applyAction('a', const Delete(), expected: Placement.inbox)), isA<ActionApplied>());
    expect(okValue(await h.provider.applyAction('b', const Delete(), expected: Placement.inbox)), isA<ActionApplied>());
    expect((await h.current('a')).labelIds, [trashLabelId]);
    expect(h.requests.map((r) => r.method), isNot(contains('DELETE')));
    final moves = h.requests.where((r) => r.url.path.endsWith('/move'));
    expect(moves.map((r) => r.body), everyElement(contains('"deleteditems"')));
    expect(moves, hasLength(2));
  });

  test('already as wanted: one read of the message and no write', () async {
    final h = GraphHarness()..deliver(msg('a', isRead: true));
    expect(okValue(await h.provider.applyAction('a', const MarkRead(), expected: false)), isA<ActionApplied>());
    expect(_writes(h), isEmpty);
    expect(h.requests.where((r) => r.url.path.endsWith('/messages/a')), hasLength(1));
  });

  test('Archivia moves into the well-known folder `archive`; its id stays', () async {
    final h = GraphHarness()..deliver(msg('a'));
    expect(
      okValue(await h.provider.applyAction('a', const Archive(), expected: Placement.inbox)),
      isA<ActionApplied>(),
    );
    expect(h.requests.singleWhere((r) => r.url.path.endsWith('/move')).body, contains('"archive"'));
    expect((await h.current('a')).labelIds, ['f-archive']);
  });

  test('no `archive` folder (404): «Archivio» is created (idempotent: the second message finds it) and the messages go there', () async {
    final h = GraphHarness(hasArchive: false)
      ..deliver(msg('a'))
      ..deliver(msg('b'));
    expect(
      okValue(await h.provider.applyAction('a', const Archive(), expected: Placement.inbox)),
      isA<ActionApplied>(),
    );
    expect(
      okValue(await h.provider.applyAction('b', const Archive(), expected: Placement.inbox)),
      isA<ActionApplied>(),
    );
    expect((await h.current('a')).labelIds, ['f-archivio']);
    expect((await h.current('b')).labelIds, ['f-archivio']);
  });

  test('an Etichetta whose folder is gone is refused, the message stays', () async {
    final h = GraphHarness()..deliver(msg('a'));
    expect(await h.provider.applyAction('a', const ApplyLabel('f-gone'), expected: false), isErr<RejectedFailure>());
    expect((await h.current('a')).labelIds, [inboxLabelId]);
  });

  test('deleted between the read and the move: messaggioSparito', () async {
    final h = GraphHarness()..deliver(msg('a'));
    h.onRequest = (r) {
      if (r.url.path.endsWith('/move')) h.removeRemotely('a');
    };
    expect(
      okValue(await h.provider.applyAction('a', const Delete(), expected: Placement.inbox)),
      isA<ActionMessageGone>(),
    );
  });

  test(
    'a message that never stops changing under the write is not applied blind: an error after three tries',
    () async {
      final h = GraphHarness()..deliver(msg('a'));
      // Every write finds a new etag.
      h.onRequest = (r) {
        if (r.method == 'PATCH') h.deliver(msg('a', isStarred: !(h.requests.length.isEven)));
      };
      expect(await h.provider.applyAction('a', const MarkRead(), expected: false), isErr<UnexpectedFailure>());
      expect(h.requests.where((r) => r.method == 'PATCH'), hasLength(3));
      expect((await h.current('a')).isRead, isFalse);
    },
  );

  test(
    'every v1 Azione: applied when the value is the expected one, nothing written when it is the wanted one',
    () async {
      final cases = <(MailAction, Object, Message, Message)>[
        (const MarkRead(), false, msg('a'), msg('a', isRead: true)),
        (const MarkUnread(), true, msg('a', isRead: true), msg('a')),
        (const Star(), false, msg('a'), msg('a', isStarred: true, labelIds: const [inboxLabelId, starredLabelId])),
        (const Unstar(), true, msg('a', isStarred: true), msg('a')),
        (const Archive(), Placement.inbox, msg('a'), msg('a', labelIds: const ['f-archive'])),
        (const Delete(), Placement.inbox, msg('a'), msg('a', labelIds: const [trashLabelId])),
        (const ApplyLabel(_viaggi), false, msg('a'), msg('a', labelIds: const [_viaggi])),
        (const RemoveLabel(_viaggi), true, msg('a', labelIds: const [_viaggi]), msg('a')),
      ];
      for (final (action, before, from, wanted) in cases) {
        final h = GraphHarness()..deliver(from);
        expect(
          okValue(await h.provider.applyAction('a', action, expected: before)),
          isA<ActionApplied>(),
          reason: '$action',
        );
        final now = await h.current('a');
        expect(
          [now.isRead, now.isStarred, ...now.labelIds],
          [wanted.isRead, wanted.isStarred, ...wanted.labelIds],
          reason: '$action',
        );
        final done = _writes(h).length;
        expect(okValue(await h.provider.applyAction('a', action, expected: before)), isA<ActionApplied>());
        expect(_writes(h), hasLength(done), reason: 'again: already as wanted, nothing written for $action');
      }
    },
  );

  test('Unstar sends notFlagged and clears the Stella', () async {
    final h = GraphHarness()..deliver(msg('a', isStarred: true));
    okValue(await h.provider.applyAction('a', const Unstar(), expected: true));
    expect(h.requests.singleWhere((r) => r.method == 'PATCH').body, '{"flag":{"flagStatus":"notFlagged"}}');
    expect((await h.current('a')).isStarred, isFalse);
  });

  test('a system Etichetta moves to its well-known folder: Cestino is `deleteditems`', () async {
    final h = GraphHarness()..deliver(msg('a'));
    expect(
      okValue(await h.provider.applyAction('a', const ApplyLabel(trashLabelId), expected: false)),
      isA<ActionApplied>(),
    );
    expect(h.requests.singleWhere((r) => r.url.path.endsWith('/move')).body, contains('"deleteditems"'));
    expect((await h.current('a')).labelIds, [trashLabelId]);
  });
}
