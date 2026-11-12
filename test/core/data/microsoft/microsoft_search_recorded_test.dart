// The Graph search (#209) on the responses of test/fixtures/graph: no network.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:postino/core/data/microsoft/graph_kql.dart';
import 'package:postino/core/data/microsoft/graph_message_parser.dart';
import 'package:postino/core/data/microsoft/graph_search.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_recorded.dart';

const _wellKnown = {'inbox', 'sentitems', 'drafts', 'deleteditems', 'junkemail', 'outbox'};
const _query = SearchQuery(terms: ['preventivo']);

/// Graph answering `$search` with [first] (page 1: s1 unread and s2 read of one Conversazione, s3 in Spam; a
/// next page), then page 2 (s4, read, with a Stella, in Viaggi); the folders of the fixtures.
RecordedGraph _graph({String first = 'search_page1'}) => RecordedGraph(
  (r, path) => switch (path.split('/')) {
    ['messages'] => graphFixture(r.url.queryParameters.containsKey(r'$skip') ? 'search_page2' : first),
    ['mailFolders', final name] when _wellKnown.contains(name) => graphFixture('folder_$name'),
    ['mailFolders'] => graphFixture('folders'),
    ['mailFolders', final id, 'childFolders'] when id == folderId('lavoro') => graphFixture('folders_lavoro'),
    _ => fail('unexpected ${r.method} $path'),
  },
);

Iterable<Uri> _searches(RecordedGraph g) => g.urls.where((u) => u.path.endsWith('/messages'));

void main() {
  test(r'one $search over the mailbox with the KQL, 50 per page, the sync $select; Spam is dropped', () async {
    final g = _graph();
    final page = okValue(await g.provider.search(_query));
    final first = _searches(g).single;
    expect(first.queryParameters[r'$search'], graphKql(_query));
    expect(first.queryParameters[r'$top'], '50');
    expect(first.queryParameters[r'$select'], graphMessageSelect);
    expect(first.queryParameters.containsKey(r'$filter'), isFalse, reason: r'$filter does not go with $search');
    expect(page.messages.map((m) => m.id), [messageIdOf('s1'), messageIdOf('s2')]);
    expect(page.messages.first.labelIds, [inboxLabelId]);
    expect(page.messages.first.hasAttachments, isTrue);
    expect(page.conversationIds, {'conv-s1'});
    expect(page.nextPageToken, startsWith('3 https://graph.microsoft.com/'));
    expect(page.limit, isNull);
  });

  test('the next page follows `@odata.nextLink`; the last has no token', () async {
    final g = _graph();
    final next = okValue(await g.provider.search(_query)).nextPageToken;
    final page = okValue(await g.provider.search(_query, pageToken: next));
    expect(_searches(g).last.queryParameters[r'$skip'], '50');
    expect(page.messages.single.id, messageIdOf('s4'));
    expect(page.messages.single.labelIds, [folderId('viaggi'), starredLabelId]);
    expect(page.nextPageToken, isNull);
  });

  test('a message already stored gives only its Conversazione', () async {
    final page = okValue(await _graph().provider.search(_query, stored: {messageIdOf('s1'), messageIdOf('s2')}));
    expect(page.messages, isEmpty);
    expect(page.conversationIds, {'conv-s1'});
  });

  test('unread here: of a page with read and unread messages only the unread come', () async {
    final page = okValue(await _graph().provider.search(const SearchQuery(terms: ['preventivo'], unread: true)));
    expect(page.messages.map((m) => m.id), [messageIdOf('s1')]);
  });

  test('a page the local filters empty is not the end: the next comes in the same call', () async {
    final g = _graph();
    final page = okValue(await g.provider.search(const SearchQuery(terms: ['preventivo'], starred: true)));
    expect(_searches(g), hasLength(2));
    expect(page.messages.map((m) => m.id), [messageIdOf('s4')]);
    expect(page.nextPageToken, isNull);
  });

  test('the page that ends at 1.000 results says so', () async {
    final g = _graph();
    final link = okValue(await g.provider.search(_query)).nextPageToken!.split(' ').last;
    expect(okValue(await g.provider.search(_query, pageToken: '999 $link')).limit, graphSearchLimit);
    expect(okValue(await g.provider.search(_query, pageToken: '3 $link')).limit, isNull);
  });

  test('a token that leads to another host is NotFound: the access token goes nowhere else', () async {
    final g = _graph();
    expect(
      await g.provider.search(_query, pageToken: '3 https://evil.example.com/v1.0/me/messages'),
      isErr<NotFoundFailure>(),
    );
    expect(await g.provider.search(_query, pageToken: 'garbage'), isErr<NotFoundFailure>());
    expect(g.urls.where((u) => u.host == 'evil.example.com'), isEmpty);
  });

  test('nothing to look for asks Graph nothing', () async {
    final g = _graph();
    expect(okValue(await g.provider.search(const SearchQuery(unread: true))).messages, isEmpty);
    expect(g.requests, isEmpty);
  });

  test('429 with Retry-After: one retry after the wait, then a RateLimitFailure', () async {
    final g = RecordedGraph((r, path) => graphFixture('rate_limited'));
    expect(await g.provider.search(_query), isErr<RateLimitFailure>());
    expect(g.sleeps, [const Duration(seconds: 2)]);
    expect(_searches(g), hasLength(2));
  });

  test('a 401 after the refresh is an AuthFailure', () async {
    final g = RecordedGraph((r, path) => http.Response('{"error":{"code":"InvalidAuthenticationToken"}}', 401));
    expect(await g.provider.search(_query), isErr<AuthFailure>());
    expect(g.urls.where((u) => u.host == tokenHost), isNotEmpty, reason: 'refreshed first');
  });
}
