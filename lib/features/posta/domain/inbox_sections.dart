import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';

/// The sections of the posta in arrivo (#366), in their order: Da leggere, Contrassegnate, Letti.
enum InboxSection() {
  unread,
  starred,
  read,
}

/// How many Conversazioni Da leggere and Contrassegnate show before «Mostra tutti».
const sectionPreview = 3;

/// A Conversazione of a list: (Account id, Conversazione id).
typedef ConversationKey = (String, String);

/// The focused Conversazione and the section it stays in while it has the focus.
typedef HeldConversation = (ConversationKey, InboxSection);

/// The key of [e]'s Conversazione.
ConversationKey keyOf(InboxEntry e) => (e.account.id, e.message.conversationId);

/// A message of the Conversazione has the Stella: the row's labels are those of all of them.
bool isStarred(InboxEntry e) => e.message.labelIds.contains(starredLabelId);

/// The focus rule: [focus] (the open Conversazione, or the row with the focus) keeps the section it is in, [before], when it takes the focus,
/// whatever then happens to its Stella or its unread messages; the hold ends when the focus moves on.
/// Null with no focus, and while the focus is not in the list yet.
HeldConversation? holdFocus(ConversationKey? focus, HeldConversation? held, InboxSections? before) {
  if (focus == null) return null;
  if (held?.$1 == focus) return held;
  final at = before?.sectionOf(focus);
  return at == null ? null : (focus, at);
}

/// The Conversazioni of the posta in arrivo by section, each in one only, newest first as they come.
class InboxSections._(final Map<InboxSection, List<InboxEntry>> _by, final HeldConversation? _held) {
  /// Splits [entries]: with an unread message in Da leggere (even with a Stella), else with a Stella in Contrassegnate, else in Letti;
  /// [held] stays where the focus rule keeps it.
  factory InboxSections.of(List<InboxEntry> entries, {HeldConversation? held}) {
    final by = {for (final s in InboxSection.values) s: <InboxEntry>[]};
    for (final e in entries) {
      final section = held != null && keyOf(e) == held.$1
          ? held.$2
          : e.unread
          ? InboxSection.unread
          : isStarred(e)
          ? InboxSection.starred
          : InboxSection.read;
      by[section]!.add(e);
    }
    return InboxSections._(by, held);
  }

  /// Every Conversazione of [s].
  List<InboxEntry> all(InboxSection s) => _by[s]!;

  /// What the list shows of [s]: the [sectionPreview] newest of Da leggere and Contrassegnate, all of Letti.
  /// The held Conversazione past them (newer ones arrived since it took the focus) takes the place of the last.
  List<InboxEntry> shown(InboxSection s) {
    if (!hasMore(s)) return all(s);
    final first = all(s).take(sectionPreview).toList();
    final held = _held == null ? null : all(s).where((e) => keyOf(e) == _held.$1).firstOrNull;
    if (held == null || first.contains(held)) return first;
    return [...first.take(sectionPreview - 1), held];
  }

  /// [s] has more than it shows: «Mostra tutti».
  bool hasMore(InboxSection s) => s != InboxSection.read && all(s).length > sectionPreview;

  /// [s] has a heading: it is not empty, and Letti only under another section (else the list is as without sections).
  bool headed(InboxSection s) =>
      all(s).isNotEmpty &&
      (s != InboxSection.read || all(InboxSection.starred).isNotEmpty || all(InboxSection.unread).isNotEmpty);

  /// The section [key]'s Conversazione is in, null when it is not in the list.
  InboxSection? sectionOf(ConversationKey key) =>
      InboxSection.values.where((s) => all(s).any((e) => keyOf(e) == key)).firstOrNull;
}
