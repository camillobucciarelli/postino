import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/inbox_repository.dart';
import '../domain/mail_provider.dart';
import '../domain/message.dart';
import 'postino_database.dart';

@lazySingleton
class MailStore implements InboxRepository {
  MailStore(this._db);
  final PostinoDatabase _db;

  Future<void> addAccount(Account a) => _db.accountsDao.upsert(a);

  Future<List<Account>> accounts() async => [
    for (final r in await _db.accountsDao.byPosition()) _account(r),
  ];

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  Future<void> applySync(
    String accountId,
    SyncBatch batch, {
    bool fullSnapshot = false,
  }) => _db.messagesDao.applySync(
    accountId,
    batch,
    fullSnapshot: fullSnapshot,
  );

  @override
  Stream<List<InboxEntry>> watchUnifiedInbox() =>
      _db.messagesDao.watchUnifiedInbox().map(
        (rows) => [
          for (final (a, m) in rows)
            InboxEntry(account: _account(a), message: _message(m)),
        ],
      );

  static Account _account(AccountRow r) => Account(
    id: r.id,
    address: r.address,
    provider: r.provider,
    color: r.color,
    position: r.position,
    status: r.status,
  );

  static Message _message(MessageRow r) => Message(
    id: r.id,
    messageId: r.messageId,
    conversationId: r.conversationId,
    labelIds: const [inboxLabelId],
    isRead: r.isRead,
    isStarred: r.isStarred,
    from: r.sender,
    to: r.recipients.split(','),
    subject: r.subject,
    snippet: r.snippet,
    date: DateTime.fromMillisecondsSinceEpoch(r.date, isUtc: true),
  );
}

@module
abstract class MailStoreModule {
  /// The UI sees the store only through [InboxRepository].
  @lazySingleton
  InboxRepository inboxRepository(MailStore store) => store;
}
