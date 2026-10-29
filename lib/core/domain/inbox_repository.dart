import 'account.dart';
import 'message.dart';

class InboxEntry {
  const InboxEntry({required this.message, required this.account});
  final Message message;
  final Account account;
}

/// What the UI reads: only from the local database, never from a Provider (ADR 0003).
abstract interface class InboxRepository {
  /// Posta unificata: inbox of every Account, newest first; re-emits after each write.
  Stream<List<InboxEntry>> watchUnifiedInbox();

  /// Messages of one Account carrying [labelId] ([inboxLabelId] for its inbox), newest first.
  Stream<List<InboxEntry>> watchMessages(String accountId, String labelId);

  /// The Etichette of one Account, by name; never those of another.
  Stream<List<Label>> watchLabels(String accountId);
}
