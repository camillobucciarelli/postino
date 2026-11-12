import '../../domain/mailbox.dart';
import '../../domain/message.dart';

/// A reply without references joins a message with its subject only if that came at most this long before it.
const threadWindow = Duration(days: 30);

/// How many parents (or subject predecessors) a message's root is looked for through; a loop ends there.
const maxThreadDepth = 50;

/// Reply and forward prefixes, repeated or numbered (`Re: R: Fwd:`, `Re[2]:`): English, Italian (R, I), German (AW).
final _prefixes = RegExp(r'^\s*((re|fwd?|r|i|aw)\s*(\[\d+\])?\s*:\s*)+', caseSensitive: false);

/// [subject] without its reply and forward prefixes, spaces compressed, lowercase.
String normalizedSubject(String subject) =>
    subject.replaceFirst(_prefixes, '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

/// Whether [subject] starts like a reply or a forward.
bool hasReplyPrefix(String subject) => _prefixes.hasMatch(subject);

/// A message to thread, with the `In-Reply-To` it answers.
typedef ThreadInput = ({Message message, String? inReplyTo});

/// IMAP has no thread id (#28 «Thread»): each message of [messages] gets the Message-ID of its Conversazione's
/// root, stable from one sync to the next. In order: the first `References` entry; else, with only `In-Reply-To`,
/// the parent's Conversazione when [known] holds the parent, the parent's Message-ID otherwise; else, for a reply
/// without references (a prefixed subject), the Conversazione of the earliest message of [known] with the same
/// normalized subject in the [threadWindow] before it and a participant in common, the Account's own [address]
/// apart (it is in every message); else its own Message-ID (its Provider id when it has none). A Spam message is
/// a Conversazione of its own, by its Provider id: it never shows inside an inbox Conversazione (#185).
/// [known] holds [messages] and whatever else the caller knows of the mailbox.
List<Message> threadMessages(
  List<ThreadInput> messages, {
  required Iterable<ThreadInput> known,
  required String address,
}) {
  final byId = {for (final k in known) k.message.messageId: k};
  final me = address.toLowerCase();
  final memo = <ThreadInput, String>{};

  Set<String> participants(Message m) => {
    m.from.toLowerCase(),
    for (final a in [...m.to, ...m.cc]) parseMailbox(a).address.toLowerCase(),
  }..remove(me);

  String root(ThreadInput t, int depth) {
    if (memo[t] case final id?) return id;
    final m = t.message;
    String own() => m.messageId.isEmpty ? m.id : m.messageId;
    final id = switch ((m.references, t.inReplyTo)) {
      ([final first, ...], _) => first,
      (_, final parent?) => switch (byId[parent]) {
        final p? when depth < maxThreadDepth && p != t => root(p, depth + 1),
        _ => parent,
      },
      _ when hasReplyPrefix(m.subject) && depth < maxThreadDepth => switch (_earliestSibling(t, known, participants)) {
        final s? => root(s, depth + 1),
        null => own(),
      },
      _ => own(),
    };
    return memo[t] = id;
  }

  return [
    for (final t in messages)
      withConversation(t.message, t.message.labelIds.contains(spamLabelId) ? t.message.id : root(t, 0)),
  ];
}

/// The earliest message of [known] that [t] may answer by subject: same normalized subject, sent before it
/// within [threadWindow], a participant in common.
ThreadInput? _earliestSibling(
  ThreadInput t,
  Iterable<ThreadInput> known,
  Set<String> Function(Message m) participants,
) {
  final m = t.message;
  final subject = normalizedSubject(m.subject);
  final people = participants(m);
  ThreadInput? best;
  for (final k in known) {
    final c = k.message;
    if (c.date.isBefore(m.date) &&
        m.date.difference(c.date) <= threadWindow &&
        normalizedSubject(c.subject) == subject &&
        participants(c).any(people.contains) &&
        (best == null || c.date.isBefore(best.message.date))) {
      best = k;
    }
  }
  return best;
}

/// [m] in the Conversazione [conversationId], with the list preview [snippet] where given.
Message withConversation(Message m, String conversationId, {String? snippet}) => Message(
  id: m.id,
  messageId: m.messageId,
  conversationId: conversationId,
  labelIds: m.labelIds,
  isRead: m.isRead,
  isStarred: m.isStarred,
  from: m.from,
  fromName: m.fromName,
  to: m.to,
  cc: m.cc,
  bcc: m.bcc,
  subject: m.subject,
  snippet: snippet ?? m.snippet,
  date: m.date,
  replyTo: m.replyTo,
  references: m.references,
  hasAttachments: m.hasAttachments,
);
