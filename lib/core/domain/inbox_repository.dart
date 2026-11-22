import 'package:equatable/equatable.dart';

import 'account.dart';
import 'conflict.dart';
import 'draft_conflict.dart';
import 'message.dart';

/// A Conversazione in a list: its latest [message], how many messages it has, and whether any is unread.
class const InboxEntry({
  /// The latest message of the Conversazione; its `labelIds` are those of every message of it.
  required final Message message,

  /// L'Account a cui appartiene.
  required final Account account,

  /// Numero di messaggi della Conversazione.
  required final int count,

  /// Se almeno un messaggio è da leggere.
  required final bool unread,

  /// Send state of an Inviati row (queued, offline, failed): spoken with the row, not only shown in its preview.
  final String? status,
}) extends Equatable {
  /// Crea una riga di elenco.
  this;

  @override
  List<Object?> get props => [message, account, count, unread, status];
}

/// A message of an open Conversazione, with its body once downloaded.
typedef ConversationMessage = ({Message message, MessageBody? body});

/// A message waiting in the outbox (#36): [sendAfter] (ms since epoch, UTC) is when Annulla invio ends and it goes.
/// [failed]: the Provider refused it for good (too big, Bozza gone); it waits for the user, never retried.
class const OutgoingEntry({
  /// Il messaggio in attesa di partire.
  required final OutgoingMessage message,

  /// Quando finisce Annulla invio (ms da epoch, UTC).
  required final int sendAfter,

  /// Il Provider l'ha rifiutato per sempre: attende l'utente.
  final bool failed = false,
}) extends Equatable {
  /// Crea una voce della Coda d'uscita; `failed` parte falso.
  this;

  @override
  List<Object?> get props => [message, sendAfter, failed];
}

/// What the UI reads: only from the local database, never from a Provider (ADR 0003).
abstract interface class InboxRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

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

  /// The messages of one Account waiting to be sent (Annulla invio, offline), newest first.
  Stream<List<OutgoingEntry>> watchOutbox(String accountId);

  /// The Etichette of one Account, by name; never those of another.
  Stream<List<Label>> watchLabels(String accountId);

  /// The Etichette of every Account by Account id, by name, folders of the user included (the drawer, #311).
  Stream<Map<String, List<Label>>> watchAllLabels();

  /// Every stored message of a Conversazione, oldest first; with [view], the Etichetta it is opened from, only those
  /// that view shows: from any but the Cestino or Spam, not the messages in the Cestino or Spam.
  Stream<List<ConversationMessage>> watchConversation(String accountId, String conversationId, {String? view});

  /// One stored message, or null while it is not stored (a Conflitto names its message by id only).
  Stream<Message?> watchMessage(String accountId, String messageId);

  /// The open Conflitti (ADR 0008), of every Account or only of [accountId].
  Stream<List<Conflict>> watchConflicts({String? accountId});

  /// The open Conflitti of the Bozze (#149), of every Account or only of [accountId].
  Stream<List<DraftConflict>> watchDraftConflicts({String? accountId});
}
