// Microsoft adapter: Conversazioni on the responses of test/fixtures/graph. No network.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:postino/core/domain/message.dart';

import '../../../support/gmail_recorded.dart' show okValue;
import '../../../support/graph_recorded.dart';

const _wellKnown = {'inbox', 'sentitems', 'drafts', 'deleteditems', 'junkemail', 'outbox'};

http.Response _route(http.Request r, String path) => switch (path.split('/')) {
  ['messages'] => graphFixture('conversation_c1'),
  ['mailFolders', final name] when _wellKnown.contains(name) => graphFixture('folder_$name'),
  _ => fail('unexpected ${r.method} $path'),
};

void main() {
  test('a Conversazione is asked of the whole mailbox: the old reply in Inviati comes with its Etichetta', () async {
    final g = RecordedGraph(_route);
    final messages = okValue(await g.provider.fetchConversation('conv-c1'));
    expect(messages.map((m) => (m.id, m.labelIds.single, m.date.year, m.date.month)), [
      ('msg-f1', inboxLabelId, 2026, 10),
      ('msg-f9', sentLabelId, 2026, 6),
    ]);
    final asked = g.requests.firstWhere((r) => r.url.path.endsWith('/messages'));
    expect(asked.url.queryParameters[r'$filter'], "conversationId eq 'conv-c1'");
    expect(asked.url.queryParameters[r'$select']!.split(','), isNot(contains('body')), reason: 'headers only');
    expect(asked.url.path, isNot(contains('mailFolders')), reason: 'no folder, no date window');
  });

  test('a quote in a Conversazione id is doubled in the filter', () async {
    final g = RecordedGraph(_route);
    okValue(await g.provider.fetchConversation("x' or isRead eq true or conversationId eq 'y"));
    final asked = g.requests.firstWhere((r) => r.url.path.endsWith('/messages'));
    expect(asked.url.queryParameters[r'$filter'], "conversationId eq 'x'' or isRead eq true or conversationId eq ''y'");
  });
}
