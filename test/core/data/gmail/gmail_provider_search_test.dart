// The Gmail search (#207) on recorded HTTP responses (test/fixtures/gmail): no network.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../../support/gmail_recorded.dart';

const _f1 = '18f3a2b4c5d6e7f1';
const _f2 = '18f3a2b4c5d6e7f2';

/// Gmail answering a search with two messages of one thread and a next page.
RecordedGmail _gmail({String list = 'messages_page1'}) => RecordedGmail(
  (r, path) => switch (path) {
    'messages' => list,
    'messages/$_f1' => 'message_f1',
    'messages/$_f2' => 'message_f2',
    _ => 'not_found',
  },
);

void main() {
  test('one page of `messages.list` with the translated q, then the headers with format=metadata', () async {
    final g = _gmail();
    final page = okValue(
      await g.provider.search(
        SearchQuery(from: 'ada', after: DateTime(2025)),
        pageToken: 'p2',
      ),
    );
    final list = g.urls.first;
    expect(list.path, endsWith('/messages'));
    expect(list.queryParameters['q'], 'from:"ada" after:${DateTime(2025).millisecondsSinceEpoch ~/ 1000}');
    expect(list.queryParameters['maxResults'], '50');
    expect(list.queryParameters['pageToken'], 'p2');
    expect(list.queryParameters.containsKey('includeSpamTrash'), isFalse, reason: 'never Spam nor Cestino');
    final gets = g.urls.skip(1).toList();
    expect(gets.map((u) => u.queryParameters['format']), everyElement('metadata'));
    expect(page.messages.map((m) => m.id), [_f1, _f2], reason: 'in the order Gmail listed them');
    expect(page.messages.first.conversationId, _f1);
    expect(page.conversationIds, {_f1});
    expect(page.nextPageToken, '08765432109876543210');
  });

  test('a message already stored is not fetched again: one GET less', () async {
    final g = _gmail();
    final page = okValue(await g.provider.search(const SearchQuery(terms: ['cena']), stored: {_f1}));
    expect(g.urls.where((u) => u.path.endsWith(_f1)), isEmpty);
    expect(page.messages.map((m) => m.id), [_f2]);
    expect(page.conversationIds, {_f1});
  });

  test('the last page has no token; nothing to look for asks Gmail nothing', () async {
    final last = _gmail(list: 'messages_page2');
    expect(okValue(await last.provider.search(const SearchQuery(terms: ['cena']))).nextPageToken, isNull);
    final empty = _gmail();
    expect(okValue(await empty.provider.search(const SearchQuery())).messages, isEmpty);
    expect(empty.requests, isEmpty);
  });

  test('the quota hit is retried, then a RateLimitFailure', () async {
    final g = RecordedGmail((r, path) => 'rate_limited');
    expect(await g.provider.search(const SearchQuery(terms: ['cena'])), isErr<RateLimitFailure>());
    expect(g.sleeps, isNotEmpty);
  });

  test('a 401 after the refresh is an AuthFailure', () async {
    final g = RecordedGmail((r, path) => 'unauthorized');
    expect(await g.provider.search(const SearchQuery(terms: ['cena'])), isErr<AuthFailure>());
    expect(g.urls.where((u) => u.host == 'oauth2.googleapis.com'), isNotEmpty, reason: 'refreshed first');
  });
}
