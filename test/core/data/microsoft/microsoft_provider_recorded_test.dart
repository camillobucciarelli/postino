// Microsoft adapter on the responses of test/fixtures/graph: folders, initial sync over pages, delta. No network.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:postino/core/data/microsoft/graph_cursor.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_recorded.dart';

const _wellKnown = {'inbox', 'sentitems', 'drafts', 'deleteditems', 'junkemail', 'outbox'};

/// The mailbox of the fixtures; [delta] answers each folder's delta rounds after the first (`$deltatoken`).
http.Response Function(http.Request, String) _route({
  String folderDelta = 'folders_delta_empty',
  String folders = 'folders',
  http.Response Function(String folder)? delta,
}) => (r, path) {
  final token = r.url.queryParameters.containsKey(r'$deltatoken');
  return switch (path.split('/')) {
    ['mailFolders', 'delta'] => graphFixture(token ? folderDelta : 'folders_delta'),
    // A message reported @removed and gone for good (deleted, not moved).
    ['messages', _] => graphFixture('not_found'),
    ['mailFolders', final name] when _wellKnown.contains(name) => graphFixture('folder_$name'),
    ['mailFolders'] when r.method == 'POST' => graphFixture('folder_created'),
    ['mailFolders'] => graphFixture(folders),
    ['mailFolders', final id, 'childFolders'] when id == folderId('lavoro') => graphFixture('folders_lavoro'),
    ['mailFolders', final id, 'messages', 'delta'] when token && delta != null => delta(id),
    ['mailFolders', final id, 'messages', 'delta'] when id == folderId('inbox') && !token => graphFixture(
      r.url.queryParameters.containsKey(r'$skiptoken') ? 'messages_page2' : 'messages_page1',
    ),
    ['mailFolders', final id, 'messages', 'delta'] => graphFixture('delta_empty', folder: id),
    _ => fail('unexpected ${r.method} $path'),
  };
};

Iterable<String> _deltaFolders(RecordedGraph g) => g.requests
    .map(graphPath)
    .where((p) => p.endsWith('/messages/delta'))
    .map((p) => p.split('/')[1].replaceFirst(folderId(''), ''));

void main() {
  test('initial sync: the folders, 90 days of every synced folder over its pages, the inbox bodies', () async {
    final g = RecordedGraph(_route());
    final pages = <List<String>>[];
    final batch = okValue(
      await g.provider.initialSync(onPage: (messages, _) async => pages.add([for (final m in messages) m.id])),
    );

    expect(batch.labels!.map((l) => (l.id, l.name, l.kind)), [
      (folderId('archive'), 'Archivio', LabelKind.cartella),
      (folderId('lavoro'), 'Lavoro', LabelKind.cartella),
      (folderId('progetti'), 'Lavoro/Progetti', LabelKind.cartella),
      (folderId('viaggi'), 'Viaggi', LabelKind.cartella),
    ], reason: 'the well-known folders by id, whatever their Italian names; a subfolder by its full path');
    expect(_deltaFolders(g).toSet(), {'inbox', 'drafts', 'sentitems', 'archive', 'lavoro', 'progetti', 'viaggi'});
    expect(_deltaFolders(g).first, 'inbox', reason: 'the inbox first: its page is the first the user sees');
    expect(
      g.requests.map(graphPath).where((p) => p.contains('deleteditems/childFolders')),
      isEmpty,
      reason: 'nothing inside Cestino is synced',
    );

    final deltas = g.urls.where((u) => u.path.endsWith('/messages/delta')).toList();
    final first = deltas.first.queryParameters;
    expect(first[r'$filter'], 'receivedDateTime ge 2026-07-30T12:00:00.000Z');
    expect(first[r'$orderby'], 'receivedDateTime desc');
    expect(first[r'$select']!.split(','), containsAll(['id', 'conversationId', 'isRead', 'flag', 'body']));
    expect(
      deltas.where((u) => !u.path.contains(folderId('inbox'))).map((u) => u.queryParameters[r'$select']!.split(',')),
      everyElement(isNot(contains('body'))),
      reason: 'bodies only for the inbox (ADR 0003)',
    );
    expect(
      g.requests.where((r) => r.url.host == 'graph.microsoft.com').map((r) => r.headers['prefer']),
      everyElement(contains('ImmutableId')),
    );

    expect(pages.first, [messageIdOf('f1'), messageIdOf('f2')]);
    expect(pages[1], [messageIdOf('f3')], reason: 'the @odata.nextLink page');
    expect(batch.messages.map((m) => m.id), unorderedEquals(['f1', 'f2', 'f3'].map(messageIdOf)));
    expect(batch.messages.map((m) => m.labelIds.first).toSet(), {inboxLabelId});
    expect(batch.bodies.keys, unorderedEquals(['f1', 'f2', 'f3'].map(messageIdOf)));

    final cursor = GraphCursor.decode(batch.cursor)!;
    expect(cursor.folders, endsWith('_F1'));
    expect(cursor.messages[folderId('inbox')]!.label, inboxLabelId);
    expect(cursor.messages[folderId('inbox')]!.link, endsWith('_D1'));
  });

  test('incremental sync: new, read, starred, moved and deleted messages; the Etichette unchanged', () async {
    final g = RecordedGraph(
      _route(
        delta: (id) => id == folderId('inbox')
            ? graphFixture('delta_inbox_changes')
            : id == folderId('viaggi')
            ? graphFixture('delta_viaggi_moved')
            : graphFixture('delta_empty', folder: id),
      ),
    );
    final first = okValue(await g.provider.initialSync());
    final next = okValue(await g.provider.incrementalSync(first.cursor));

    final byId = {for (final m in next.messages) m.id.replaceFirst(messageIdOf(''), ''): m};
    expect(byId.keys, unorderedEquals(['f1', 'f2', 'f3', 'f4']));
    expect(byId['f1']!.isRead, isTrue);
    expect(byId['f2']!.isStarred, isTrue);
    expect(byId['f2']!.labelIds, [inboxLabelId, starredLabelId]);
    expect(byId['f3']!.labelIds, [folderId('viaggi')], reason: 'moved: removed from the inbox, new in Viaggi');
    expect(next.removedMessageIds, [messageIdOf('f9')], reason: 'the moved message stays: one message, same id');
    expect(
      g.urls.where((u) => u.path.endsWith('/messages/${messageIdOf('f9')}')).single.queryParameters[r'$select'],
      'parentFolderId',
      reason: 'a removal only is checked: deleted, or moved to a folder synced earlier',
    );
    expect(next.bodies.keys, unorderedEquals(['f1', 'f2', 'f4'].map(messageIdOf)));
    expect(next.labels, isNull, reason: 'no folder changed: the stored Etichette stay');
    expect(GraphCursor.decode(next.cursor)!.messages[folderId('inbox')]!.link, endsWith('_D2'));
  });

  test('an empty delta: nothing changed, and the cursor stays valid', () async {
    final g = RecordedGraph(_route(delta: (id) => graphFixture('delta_empty', folder: id)));
    final first = okValue(await g.provider.initialSync());
    final next = okValue(await g.provider.incrementalSync(first.cursor));
    expect(next.messages, isEmpty);
    expect(next.removedMessageIds, isEmpty);
    expect(okValue(await g.provider.incrementalSync(next.cursor)).messages, isEmpty);
  });

  test('a folder created elsewhere comes as an Etichetta and starts with its first round', () async {
    final base = _route(
      folderDelta: 'folders_delta_new',
      delta: (id) => graphFixture('delta_empty', folder: id),
    );
    var created = false;
    final g = RecordedGraph(
      (r, path) => created && path == 'mailFolders' ? graphFixture('folders_fatture') : base(r, path),
    );
    final first = okValue(await g.provider.initialSync());
    created = true;
    g.requests.clear();
    final next = okValue(await g.provider.incrementalSync(first.cursor));
    expect(next.labels!.map((l) => l.name), contains('Fatture'));
    final fatture = g.urls.singleWhere((u) => u.path.contains(folderId('fatture')));
    expect(fatture.queryParameters[r'$filter'], startsWith('receivedDateTime ge'));
  });

  test('an expired delta (410) is NotFound: the core redoes the initial sync', () async {
    final g = RecordedGraph(_route(delta: (_) => graphFixture('delta_expired')));
    final first = okValue(await g.provider.initialSync());
    expect(await g.provider.incrementalSync(first.cursor), isErr<NotFoundFailure>());
  });

  test('createLabel makes a top-level folder; one that exists (ErrorFolderExists) is found and returned', () async {
    final created = okValue(await RecordedGraph(_route()).provider.createLabel('Fatture'));
    expect((created.id, created.name, created.kind), (folderId('fatture'), 'Fatture', LabelKind.cartella));

    final g = RecordedGraph((r, path) => r.method == 'POST' ? graphFixture('folder_exists') : _route()(r, path));
    final existing = okValue(await g.provider.createLabel('viaggi'));
    expect((existing.id, existing.name), (folderId('viaggi'), 'Viaggi'));
  });

  test('without a change signal the adapter reports it down', () async {
    expect(await RecordedGraph(_route()).provider.changes.first, ChangeSignal.down);
  });
}
