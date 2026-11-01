import 'account.dart';
import 'message.dart';

/// A Conversazione in a list: its latest [message], how many messages it has, and whether any is unread.
class InboxEntry {
  const InboxEntry({
    required this.message,
    required this.account,
    required this.count,
    required this.unread,
  });
  final Message message;
  final Account account;
  final int count;
  final bool unread;
}

/// A message of an open Conversazione, with its body once downloaded.
typedef ConversationMessage = ({Message message, MessageBody? body});

/// What the UI reads: only from the local database, never from a Provider (ADR 0003).
abstract interface class InboxRepository {
  /// Posta unificata: one row per Conversazione in the inbox of every Account, newest first; re-emits after each write.
  Stream<List<InboxEntry>> watchUnifiedInbox();

  /// One row per Conversazione of one Account with a message carrying [labelId] ([inboxLabelId] for its inbox), newest first.
  Stream<List<InboxEntry>> watchMessages(String accountId, String labelId);

  /// The (Account id, label id) pairs with an unread message: the dots of the icon sidebar
  /// (the inbox is [inboxLabelId], system labels included).
  Stream<Set<(String, String)>> watchUnreadFolders();

  /// The Bozze of one Account, newest first: those written here (id and Conversazione are the Message-ID, the
  /// snippet comes from the body) and those of other clients, each once; `labelIds` is `['DRAFT']`.
  Stream<List<Message>> watchDrafts(String accountId);

  /// The Etichette of one Account, by name; never those of another.
  Stream<List<Label>> watchLabels(String accountId);

  /// Every stored message of a Conversazione, oldest first.
  Stream<List<ConversationMessage>> watchConversation(
    String accountId,
    String conversationId,
  );
}
