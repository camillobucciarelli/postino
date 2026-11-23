// The Azioni on Gmail over recorded HTTP responses (test/fixtures/gmail): reads, writes and failures per request.
// The shared contract (applied, Conflitto, gone...) runs on the simulated mailbox in gmail_provider_test.dart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:postino/core/domain/action_outcome.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/gmail_recorded.dart';

const _id = '18f3a2b4c5d6e7f1';
const _modify = 'messages/$_id/modify';

/// An Azione, what the user saw, the recorded read of that state and of the wanted one, and the one write.
typedef _Case = ({MailAction action, Object expected, String seen, String done, (String, String?) write});

const _cases = <_Case>[
  (
    action: MarkRead(),
    expected: false,
    seen: 'unread_inbox',
    done: 'inbox',
    write: (_modify, '{removeLabelIds: [UNREAD]}'),
  ),
  (
    action: MarkUnread(),
    expected: true,
    seen: 'inbox',
    done: 'unread_inbox',
    write: (_modify, '{addLabelIds: [UNREAD]}'),
  ),
  (action: Star(), expected: false, seen: 'inbox', done: 'starred_inbox', write: (_modify, '{addLabelIds: [STARRED]}')),
  (
    action: Unstar(),
    expected: true,
    seen: 'starred_inbox',
    done: 'inbox',
    write: (_modify, '{removeLabelIds: [STARRED]}'),
  ),
  (
    action: Archive(),
    expected: Placement.inbox,
    seen: 'inbox',
    done: 'archived',
    write: (_modify, '{removeLabelIds: [INBOX]}'),
  ),
  (action: Delete(), expected: Placement.inbox, seen: 'inbox', done: 'trash', write: ('messages/$_id/trash', null)),
  (
    action: Restore(),
    expected: Placement.trash,
    seen: 'trash',
    done: 'inbox',
    write: (_modify, '{addLabelIds: [INBOX], removeLabelIds: [TRASH]}'),
  ),
  (
    action: ApplyLabel('Label_12'),
    expected: false,
    seen: 'inbox',
    done: 'inbox_label',
    write: (_modify, '{addLabelIds: [Label_12]}'),
  ),
  (
    action: RemoveLabel('Label_12'),
    expected: true,
    seen: 'inbox_label',
    done: 'inbox',
    write: (_modify, '{removeLabelIds: [Label_12]}'),
  ),
];

/// Gmail answering the read with the fixture `minimal_<read>` and any write with [write].
RecordedGmail _gmail(String read, [String write = 'message_modify']) =>
    RecordedGmail((r, path) => r.method == 'GET' ? 'minimal_$read' : write);

/// Gmail answering the read with [read] and any write with [write], both as fixture names.
RecordedGmail _answering(String read, String write) => RecordedGmail((r, path) => r.method == 'GET' ? read : write);

List<(String, String?)> _writes(RecordedGmail g) => [
  for (final http.Request r in g.requests.where((r) => r.method != 'GET' && r.url.host == 'gmail.googleapis.com'))
    (r.url.path.substring(gmailApi.length), r.body.isEmpty ? null : jsonDecode(r.body).toString()),
];

void main() {
  for (final c in _cases) {
    group('${c.action.runtimeType}', () {
      test('one minimal read, then its one write', () async {
        final g = _gmail(c.seen);
        expect(okValue(await g.provider.applyAction(_id, c.action, expected: c.expected)), isA<ActionApplied>());
        expect([for (final r in g.requests) r.method], ['GET', 'POST']);
        expect(g.requests.first.url.path, '${gmailApi}messages/$_id');
        expect(g.requests.first.url.queryParameters, {'format': 'minimal'});
        expect(_writes(g), [c.write]);
      });

      test('forced: read and write, no comparison with the expected value', () async {
        final g = _gmail(c.seen);
        expect(okValue(await g.provider.applyAction(_id, c.action)), isA<ActionApplied>());
        expect(_writes(g), [c.write]);
      });

      test('already the wanted value: applied, nothing written', () async {
        final g = _gmail(c.done);
        expect(okValue(await g.provider.applyAction(_id, c.action, expected: c.expected)), isA<ActionApplied>());
        expect(g.requests, hasLength(1));
      });

      test('a message gone, on the read or the write: messaggioSparito', () async {
        expect(
          okValue(await _answering('not_found', 'not_found').provider.applyAction(_id, c.action)),
          isA<ActionMessageGone>(),
        );
        final g = _answering('minimal_${c.seen}', 'not_found');
        expect(okValue(await g.provider.applyAction(_id, c.action, expected: c.expected)), isA<ActionMessageGone>());
      });

      test('401 is AuthFailure and 429 RateLimitFailure, on the read and on the write', () async {
        for (final (fixture, matcher) in <(String, Matcher)>[
          ('unauthorized', isErr<AuthFailure>()),
          ('rate_limited', isErr<RateLimitFailure>()),
        ]) {
          final onRead = _answering(fixture, 'message_modify');
          expect(await onRead.provider.applyAction(_id, c.action, expected: c.expected), matcher);
          expect(_writes(onRead), isEmpty);
          final onWrite = _answering('minimal_${c.seen}', fixture);
          expect(await onWrite.provider.applyAction(_id, c.action, expected: c.expected), matcher);
        }
      });

      test('an empty 204 answer to the write is applied', () async {
        final g = _gmail(c.seen, 'batch_modify');
        expect(okValue(await g.provider.applyAction(_id, c.action, expected: c.expected)), isA<ActionApplied>());
      });

      test('a read answered without labelIds is a message with no labels', () async {
        final g = _gmail('empty');
        expect(okValue(await g.provider.applyAction(_id, c.action)), isA<ActionApplied>());
      });
    });
  }

  test('another value changed elsewhere: a Conflitto with the Provider value, nothing written', () async {
    final trashed = _gmail('trash');
    expect(
      okValue(await trashed.provider.applyAction(_id, const Archive(), expected: Placement.inbox)),
      isA<ActionConflict>().having((c) => c.providerValue, 'providerValue', Placement.trash),
    );
    expect(_writes(trashed), isEmpty);
    final starred = _gmail('starred_inbox');
    expect(
      okValue(await starred.provider.applyAction(_id, const Star(), expected: false)),
      isA<ActionApplied>(),
      reason: 'already starred: the wanted value',
    );
    expect(
      okValue(await starred.provider.applyAction(_id, const MarkRead(), expected: false)),
      isA<ActionApplied>(),
      reason: 'starred elsewhere is another attribute',
    );
    final read = _gmail('inbox');
    expect(
      okValue(await read.provider.applyAction(_id, const Unstar(), expected: true)),
      isA<ActionApplied>(),
      reason: 'already not starred: the wanted value',
    );
    expect(
      okValue(await read.provider.applyAction(_id, const MarkUnread(), expected: false)),
      isA<ActionConflict>().having((c) => c.providerValue, 'providerValue', true),
    );
    expect(_writes(read), isEmpty);
  });

  test('another attribute changed elsewhere is no Conflitto: only the Azione one is written', () async {
    final g = _gmail('unread_starred_inbox_label');
    expect(okValue(await g.provider.applyAction(_id, const MarkRead(), expected: false)), isA<ActionApplied>());
    expect(_writes(g), [(_modify, '{removeLabelIds: [UNREAD]}')]);
  });

  test('Archivia out of the Cestino is one modify removing INBOX and TRASH', () async {
    final g = _gmail('trash');
    expect(
      okValue(await g.provider.applyAction(_id, const Archive(), expected: Placement.trash)),
      isA<ActionApplied>(),
    );
    expect(_writes(g), [(_modify, '{removeLabelIds: [INBOX, TRASH]}')]);
  });

  test('Elimina never conflicts', () async {
    final g = _gmail('archived');
    expect(okValue(await g.provider.applyAction(_id, const Delete(), expected: Placement.inbox)), isA<ActionApplied>());
    expect(_writes(g), [('messages/$_id/trash', null)]);
  });
}
