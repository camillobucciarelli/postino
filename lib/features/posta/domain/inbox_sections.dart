import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';

/// The sections of the posta in arrivo (#366), in their order: Contrassegnate, Da leggere, Letti.
enum InboxSection() {
  starred,
  unread,
  read,
}

/// How many Conversazioni Contrassegnate and Da leggere show before «Mostra tutti».
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
class InboxSections._(final Map<InboxSection, List<InboxEntry>> _by) {
  /// Splits [entries]: with a Stella in Contrassegnate, else with an unread message in Da leggere, else in Letti;
  /// [held] stays where the focus rule keeps it.
  factory InboxSections.of(List<InboxEntry> entries, {HeldConversation? held}) {
    final by = {for (final s in InboxSection.values) s: <InboxEntry>[]};
    for (final e in entries) {
      final section = held != null && keyOf(e) == held.$1
          ? held.$2
          : isStarred(e)
          ? InboxSection.starred
          : e.unread
          ? InboxSection.unread
          : InboxSection.read;
      by[section]!.add(e);
    }
    return InboxSections._(by);
  }

  /// Every Conversazione of [s].
  List<InboxEntry> all(InboxSection s) => _by[s]!;

  /// What the list shows of [s]: the [sectionPreview] newest of Contrassegnate and Da leggere, all of Letti.
  List<InboxEntry> shown(InboxSection s) => hasMore(s) ? all(s).take(sectionPreview).toList() : all(s);

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
