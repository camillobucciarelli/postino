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
}
