import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/features/posta/domain/inbox_sections.dart';
import 'package:postino/features/posta/presentation/list_items.dart';
import 'package:postino/i18n/strings.g.dart';

const _account = Account(id: 'a1', address: 'me@example.com', provider: ProviderKind.gmail, color: 0, position: 0);

InboxEntry _entry(int id, {bool unread = false}) => InboxEntry(
  account: _account,
  message: Message(
    id: 'm$id',
    messageId: '<m$id@example.com>',
    conversationId: 'c$id',
    labelIds: const [inboxLabelId],
    isRead: !unread,
    isStarred: false,
    from: 'ada@example.com',
    to: const ['me@example.com'],
    subject: 'Oggetto $id',
    snippet: '',
    date: DateTime.utc(2026, 11, 1, 0, 60 - id),
  ),
  count: 1,
  unread: unread,
);

/// `h:<section> <count>[+]` for a heading (+ with «Mostra tutti»), `<section>:<conversation>` for a row.
List<String> _drawn(List<ListItem> items) => [
  for (final i in items)
    i.entry == null
        ? 'h:${i.section!.name} ${i.count}${i.more ? '+' : ''}'
        // A row has no count and no «Mostra tutti».
        : '${i.section?.name}:${i.entry!.message.conversationId}${i.more || i.count != 0 ? '?' : ''}',
];

void main() {
  final list = [for (var i = 1; i <= 4; i++) _entry(i, unread: true), _entry(5)];

  test('outside the posta in arrivo: one row per Conversazione, no heading', () {
    expect(_drawn(listItems(list, null)), ['null:c1', 'null:c2', 'null:c3', 'null:c4', 'null:c5']);
  });

  test('in it: each headed section and the rows it shows', () {
    expect(_drawn(listItems(list, InboxSections.of(list))), [
      'h:unread 4+',
      'unread:c1',
      'unread:c2',
      'unread:c3',
      'h:read 1',
      'read:c5',
    ]);
  });

  test('one section only: all of it, without heading', () {
    final s = InboxSections.of(list);
    expect(_drawn(listItems(list, s, only: InboxSection.unread)), ['unread:c1', 'unread:c2', 'unread:c3', 'unread:c4']);
  });

  test('a Conversazione is told apart by its section too: moving section is leaving one and entering another', () {
    final s = InboxSections.of(list);
    final rows = listItems(list, s);
    expect(itemKey(rows[1]), (InboxSection.unread, ('a1', 'c1')));
    expect(itemKey(rows[0]), (InboxSection.unread, null));
    expect(itemKey(rows[1]), isNot(itemKey((section: InboxSection.read, entry: _entry(1), count: 0, more: false))));
  });

  test('the sections are named in the language of the app', () {
    final it = AppLocale.it.buildSync();
    expect([for (final s in InboxSection.values) sectionTitle(it, s)], ['Contrassegnate', 'Da leggere', 'Letti']);
    final en = AppLocale.en.buildSync();
    expect([for (final s in InboxSection.values) sectionTitle(en, s)], ['Starred', 'Unread', 'Read']);
  });
}
