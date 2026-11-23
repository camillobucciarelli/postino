import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/features/posta/domain/inbox_sections.dart';

const _account = Account(id: 'a1', address: 'me@example.com', provider: ProviderKind.gmail, color: 0, position: 0);

/// A Conversazione `c[id]`; the list passes them newest first.
InboxEntry _entry(int id, {bool unread = false, bool starred = false}) => InboxEntry(
  account: _account,
  message: Message(
    id: 'm$id',
    messageId: '<m$id@example.com>',
    conversationId: 'c$id',
    labelIds: [inboxLabelId, if (starred) starredLabelId],
    isRead: !unread,
    // Only the Conversazione's labels count, not the flag of its latest message.
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

List<String> _ids(List<InboxEntry> l) => [for (final e in l) e.message.conversationId];

void main() {
  test('sections in order: Contrassegnate, Da leggere, Letti; the Stella wins over unread', () {
    final s = InboxSections.of([
      _entry(1),
      _entry(2, unread: true),
      _entry(3, starred: true, unread: true),
      _entry(4, starred: true),
    ]);
    expect(InboxSection.values, [InboxSection.starred, InboxSection.unread, InboxSection.read]);
    expect(_ids(s.all(InboxSection.starred)), ['c3', 'c4'], reason: 'with a Stella even if unread');
    expect(_ids(s.all(InboxSection.unread)), ['c2']);
    expect(_ids(s.all(InboxSection.read)), ['c1']);
    expect(s.sectionOf(('a1', 'c3')), InboxSection.starred);
    expect(s.sectionOf(('a1', 'c9')), isNull);
  });

  test('the Stella of any message of the Conversazione counts, not the flag of the latest one', () {
    expect(isStarred(_entry(1, starred: true)), isTrue);
    expect(isStarred(_entry(1)), isFalse);
  });

  test('Contrassegnate and Da leggere show the 3 newest, «Mostra tutti» past 3; Letti shows all', () {
    final s = InboxSections.of([
      for (var i = 1; i <= 4; i++) _entry(i, unread: true),
      for (var i = 5; i <= 7; i++) _entry(i, starred: true),
      for (var i = 8; i <= 12; i++) _entry(i),
    ]);
    expect(_ids(s.shown(InboxSection.unread)), ['c1', 'c2', 'c3']);
    expect(s.hasMore(InboxSection.unread), isTrue, reason: '4 of them');
    expect(_ids(s.shown(InboxSection.starred)), ['c5', 'c6', 'c7']);
    expect(s.hasMore(InboxSection.starred), isFalse, reason: 'exactly 3');
    expect(s.shown(InboxSection.read), hasLength(5));
    expect(s.hasMore(InboxSection.read), isFalse);
  });

  test('an empty section has no heading; Letti only under another section', () {
    final onlyRead = InboxSections.of([_entry(1), _entry(2)]);
    expect(InboxSection.values.where(onlyRead.headed), isEmpty, reason: 'the list as before');
    final noUnread = InboxSections.of([_entry(1), _entry(2, starred: true)]);
    expect(InboxSection.values.where(noUnread.headed), [InboxSection.starred, InboxSection.read]);
    final noRead = InboxSections.of([_entry(1, unread: true)]);
    expect(InboxSection.values.where(noRead.headed), [InboxSection.unread]);
    expect(InboxSection.values.where(InboxSections.of(const []).headed), isEmpty);
  });

  test('the focus rule: the focused Conversazione keeps its section until the focus moves on', () {
    final before = InboxSections.of([_entry(1, unread: true), _entry(2)]);
    // Opened: it is read now, and starred, but it stays in Da leggere.
    final held = holdFocus(('a1', 'c1'), null, before);
    expect(held, (('a1', 'c1'), InboxSection.unread));
    final now = InboxSections.of([_entry(1, starred: true), _entry(2)], held: held);
    expect(_ids(now.all(InboxSection.unread)), ['c1']);
    expect(now.all(InboxSection.starred), isEmpty);
    // Still focused: still held, wherever its state goes.
    expect(holdFocus(('a1', 'c1'), held, now), held);
    // The focus moves on: c1 goes where its state says, c2 is held where it is.
    final next = holdFocus(('a1', 'c2'), held, now);
    expect(next, (('a1', 'c2'), InboxSection.read));
    final after = InboxSections.of([_entry(1, starred: true), _entry(2, unread: true)], held: next);
    expect(_ids(after.all(InboxSection.starred)), ['c1']);
    expect(_ids(after.all(InboxSection.read)), ['c2']);
    // No focus: nothing held; a focus not in the list yet holds nothing until it shows.
    expect(holdFocus(null, held, now), isNull);
    expect(holdFocus(('a1', 'c9'), held, now), isNull);
    expect(holdFocus(('a1', 'c1'), null, null), isNull);
  });

  test('a held Conversazione that left the list holds nothing in it', () {
    final s = InboxSections.of([_entry(2)], held: (('a1', 'c1'), InboxSection.unread));
    expect(s.all(InboxSection.unread), isEmpty);
    expect(_ids(s.all(InboxSection.read)), ['c2']);
  });

  test('the held Conversazione past the 3 newest takes the place of the third; the limit and the count stay', () {
    // c4 was opened among the 3 newest; c1 and c2 arrived since.
    const held = (('a1', 'c4'), InboxSection.unread);
    final s = InboxSections.of([for (var i = 1; i <= 5; i++) _entry(i, unread: true)], held: held);
    expect(_ids(s.shown(InboxSection.unread)), ['c1', 'c2', 'c4']);
    expect(s.hasMore(InboxSection.unread), isTrue);
    expect(s.all(InboxSection.unread), hasLength(5));
    // Among the 3 newest, or no hold: the 3 newest as they are.
    final among = InboxSections.of(
      [for (var i = 1; i <= 5; i++) _entry(i, unread: true)],
      held: (('a1', 'c2'), InboxSection.unread),
    );
    expect(_ids(among.shown(InboxSection.unread)), ['c1', 'c2', 'c3']);
    // Held in another section: this one is untouched.
    final elsewhere = InboxSections.of(
      [for (var i = 1; i <= 4; i++) _entry(i, starred: true), _entry(5)],
      held: (('a1', 'c5'), InboxSection.read),
    );
    expect(_ids(elsewhere.shown(InboxSection.starred)), ['c1', 'c2', 'c3']);
  });
}
