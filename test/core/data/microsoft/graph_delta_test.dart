// One delta round of a folder: each message in its last state across the pages, and where a message is now.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:postino/core/data/microsoft/graph_delta.dart';
import 'package:postino/core/data/microsoft/graph_http.dart';

import '../../../support/fake_platform.dart';
import '../../../support/graph_recorded.dart';

const _link = 'https://graph.microsoft.com/v1.0/me/mailFolders/f/messages/delta';

Map<String, Object?> _message(String id) => {
  'id': id,
  'conversationId': 'c-$id',
  'isRead': false,
  'receivedDateTime': '2026-10-20T10:00:00Z',
};

Map<String, Object?> _removed(String id) => {
  'id': id,
  '@removed': {'reason': 'deleted'},
};

GraphDelta _delta(Object Function(Uri url) answer) => GraphDelta(
  GraphHttp(
    graphAccount,
    graphKeychain(),
    MockClient((r) async {
      final body = answer(r.url);
      return body is int ? graphFixture('not_found') : graphJson(body);
    }),
    FakeClock(graphNow),
    client: graphTestClient,
  ),
);

void main() {
  test('changed then removed is removed; removed then changed is there, across pages', () async {
    final delta = _delta(
      (url) => url.queryParameters.containsKey(r'$skiptoken')
          ? {
              'value': [_removed('m1'), _message('m2')],
              '@odata.deltaLink': '$_link?\$deltatoken=2',
            }
          : {
              'value': [_message('m1'), _removed('m2')],
              '@odata.nextLink': '$_link?\$skiptoken=1',
            },
    );
    final d = await delta.follow('$_link?\$deltatoken=1', 'f');
    expect(d.messages.keys, ['m2']);
    expect(d.removed, {'m1'});
    expect(d.link, endsWith('deltatoken=2'));
  });

  test('where a message is now: its folder, or null once it is gone', () async {
    final delta = _delta((url) => url.path.endsWith('/m1') ? {'id': 'm1', 'parentFolderId': 'f-viaggi'} : 404);
    expect(await delta.folderOf('m1'), 'f-viaggi');
    expect(await delta.folderOf('m2'), isNull);
  });
}
