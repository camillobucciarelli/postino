import '../../../core/domain/inbox_repository.dart';
import '../../../i18n/strings.g.dart';
import '../domain/inbox_sections.dart';

/// What the list draws: a Conversazione, or the heading of a section (`entry` null) with the `count` of its
/// Conversazioni and `more` than it shows («Mostra tutti»). `section` is null outside the posta in arrivo.
typedef ListItem = ({InboxSection? section, InboxEntry? entry, int count, bool more});

/// Tells the items apart for `RowMotion`: a Conversazione that changes section leaves one and enters the other.
Object itemKey(ListItem i) => (i.section, i.entry == null ? null : keyOf(i.entry!));

/// The items of [list]: one per Conversazione outside the posta in arrivo ([sections] null); in it, each section
/// with a heading and the rows it shows, or only the section [only], all of it and without heading.
List<ListItem> listItems(List<InboxEntry> list, InboxSections? sections, {InboxSection? only}) => [
  if (sections == null)
    for (final e in list) (section: null, entry: e, count: 0, more: false)
  else if (only != null)
    for (final e in sections.all(only)) (section: only, entry: e, count: 0, more: false)
  else
    for (final s in InboxSection.values) ...[
      if (sections.headed(s)) (section: s, entry: null, count: sections.all(s).length, more: sections.hasMore(s)),
      for (final e in sections.shown(s)) (section: s, entry: e, count: 0, more: false),
    ],
];

/// The name of section [s]: Da leggere, Contrassegnate, Letti.
String sectionTitle(Translations t, InboxSection s) => switch (s) {
  InboxSection.starred => t.sezioni.starred,
  InboxSection.unread => t.sezioni.unread,
  InboxSection.read => t.sezioni.read,
};
