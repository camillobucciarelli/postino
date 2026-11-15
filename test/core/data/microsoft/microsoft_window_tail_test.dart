// A folder with more messages in the window than Graph's delta with `$filter` hands out (5000, here 3): the sync
// reads the rest of the window with the paged list, so every message of the window is in, none twice, none outside.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/graph_harness.dart';

const _cap = 3;

/// A message of [folder] received [minutes] before the start of March 2026 (inside the 90 days).
Message _at(String id, int minutes, {String folder = inboxLabelId}) => msg(
  id,
  date: GraphHarness.now.subtract(Duration(minutes: minutes)),
  labelIds: [folder],
);

Future<SyncBatch> _initial(GraphHarness graph) async => switch (await graph.provider.initialSync()) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('$failure'),
};

int _lists(GraphHarness graph) =>
    graph.requests.where((r) => r.url.path.endsWith('/mailFolders/f-inbox/messages')).length;

void main() {
  test('more messages than the cap in the window: all of them, once, and none from before it', () async {
    final graph = GraphHarness(filterCap: _cap);
    for (var i = 0; i < 7; i++) {
      graph.deliver(_at('m$i', i));
    }
    graph.deliver(msg('old', date: GraphHarness.now.subtract(syncWindow + const Duration(days: 1))));
    final ids = [for (final m in (await _initial(graph)).messages) m.id];
    expect(ids, unorderedEquals([for (var i = 0; i < 7; i++) 'm$i']));
  });

  test('exactly the cap: all of them', () async {
    final graph = GraphHarness(filterCap: _cap);
    for (var i = 0; i < _cap; i++) {
      graph.deliver(_at('m$i', i));
    }
    final ids = [for (final m in (await _initial(graph)).messages) m.id];
    expect(ids, unorderedEquals(['m0', 'm1', 'm2']));
  });

  test('under the cap: no request to the list', () async {
    final graph = GraphHarness(filterCap: _cap)
      ..deliver(_at('a', 1))
      ..deliver(_at('b', 2));
    expect((await _initial(graph)).messages, hasLength(2));
    expect(_lists(graph), 0);
  });

  test('over the cap the list is asked, `le` the oldest seen, to the end of its pages', () async {
    final graph = GraphHarness(filterCap: _cap);
    for (var i = 0; i < 7; i++) {
      graph.deliver(_at('m$i', i));
    }
    await _initial(graph);
    final lists = graph.requests.where((r) => r.url.path.endsWith('/mailFolders/f-inbox/messages')).toList();
    expect(lists, isNotEmpty);
    expect(
      lists.first.url.queryParameters[r'$filter'],
      endsWith(' and receivedDateTime le ${GraphHarness.now.subtract(const Duration(minutes: 2)).toIso8601String()}'),
    );
    expect(lists.where((r) => r.url.queryParameters.containsKey(r'$skip')), isEmpty);
  });

  test('several messages with the date of the boundary: none lost', () async {
    final graph = GraphHarness(filterCap: _cap);
    for (var i = 0; i < 5; i++) {
      graph.deliver(_at('t$i', 10));
    }
    graph
      ..deliver(_at('new', 1))
      ..deliver(_at('older', 20));
    final ids = [for (final m in (await _initial(graph)).messages) m.id];
    expect(ids, unorderedEquals(['t0', 't1', 't2', 't3', 't4', 'new', 'older']));
  });

  test('a folder found during an incremental sync, over the cap: complete', () async {
    final graph = GraphHarness(filterCap: _cap)..deliver(_at('a', 1));
    final cursor = (await _initial(graph)).cursor;
    graph.createFolderElsewhere('f-extra', 'Extra');
    for (var i = 0; i < 6; i++) {
      graph.deliver(_at('x$i', i, folder: 'f-extra'));
    }
    final batch = switch (await graph.provider.incrementalSync(cursor)) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('$failure'),
    };
    expect([for (final m in batch.messages) m.id], unorderedEquals([for (var i = 0; i < 6; i++) 'x$i']));
  });
}
