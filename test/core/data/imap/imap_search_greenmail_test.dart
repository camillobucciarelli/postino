// What the user types reaches a real server intact (#208): non-ASCII as `CHARSET UTF-8` literals, quotes and
// backslashes escaped, a command-looking text taken for text.
@Tags(['imap'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP search text', () {}, skip: reason);
    return;
  }
  late ImapHarness h;
  setUp(() async => h = await ImapHarness.create());
  tearDown(() => h.dispose());
  tearDownAll(ImapHarness.stopServer);

  Future<List<String>> subjects(SearchQuery q) async => switch (await h.provider.search(q)) {
    Ok(:final value) => [for (final m in value.messages) m.subject],
    Err(:final failure) => fail('expected Ok, got $failure'),
  };

  test('non-ASCII text and a quote with a backslash find their message', () async {
    // The text is in the body: GreenMail does not decode an encoded Subject, as real servers do.
    await h.deliver(msg('a', subject: 'Primo', snippet: 'Il caffè è pronto'));
    await h.deliver(msg('b', subject: r'Il "caso" \ chiuso'));
    await h.deliver(msg('c', subject: 'Altro'));
    expect(await subjects(const SearchQuery(terms: ['caffè'])), ['Primo']);
    expect(await subjects(const SearchQuery(phrase: 'caffè è pronto')), ['Primo']);
    expect(await subjects(const SearchQuery(subject: '"caso"')), [r'Il "caso" \ chiuso']);
    expect(await subjects(const SearchQuery(subject: r'\')), [r'Il "caso" \ chiuso']);
  });

  test('a text that looks like a command is searched, not run', () async {
    await h.deliver(msg('a', subject: 'Altro'));
    expect(await subjects(const SearchQuery(terms: ['ALL', 'x" OR ALL "y'])), isEmpty);
    expect(await subjects(const SearchQuery(phrase: 'ok\r\nA1 DELETE INBOX')), isEmpty);
    expect(await subjects(const SearchQuery(terms: ['altro'])), ['Altro'], reason: 'the mailbox is still there');
  });
}
