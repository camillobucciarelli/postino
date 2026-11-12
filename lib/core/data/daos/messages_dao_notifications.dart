import 'package:drift/drift.dart';

import '../../domain/message.dart';
import 'messages_dao.dart';

/// What the notifications' cleanup asks of the cached messages (#210): which Conversazioni are still unread in the
/// inbox, as [MessagesDao.watchUnreadFolders] counts them (an unread message and an inbox one, even another).
extension MessagesDaoNotifications on MessagesDao {
  /// Of [conversationIds], those still unread in the inbox.
  Future<Set<String>> unreadInInbox(String accountId, Iterable<String> conversationIds) async => {
    for (final chunk in _chunks(conversationIds))
      ...await (_unreadInInbox(
        accountId,
      )..where(messages.conversationId.isIn(chunk))).map((r) => r.read(messages.conversationId)!).get(),
  };

  /// Whether the Account's inbox still has an unread Conversazione.
  Future<bool> hasUnreadInInbox(String accountId) async =>
      (await (_unreadInInbox(accountId)..limit(1)).get()).isNotEmpty;

  /// The Conversazioni of the messages [messageIds] in cache.
  Future<Set<String>> conversationsOf(String accountId, Iterable<String> messageIds) async => {
    for (final chunk in _chunks(messageIds))
      ...await (selectOnly(messages, distinct: true)
            ..addColumns([messages.conversationId])
            ..where(messages.accountId.equals(accountId) & messages.id.isIn(chunk)))
          .map((r) => r.read(messages.conversationId)!)
          .get(),
  };

  /// The Account's Conversazioni unread in the inbox, by id.
  JoinedSelectStatement<HasResultSet, dynamic> _unreadInInbox(String accountId) {
    final m = messages;
    final t = alias(messages, 't');
    final l = alias(messageLabels, 'l');
    final inInbox = select(t).join([
      innerJoin(
        l,
        l.accountId.equalsExp(t.accountId) & l.messageId.equalsExp(t.id) & l.labelId.equals(inboxLabelId),
        useColumns: false,
      ),
    ])..where(t.accountId.equalsExp(m.accountId) & t.conversationId.equalsExp(m.conversationId));
    return selectOnly(m, distinct: true)
      ..addColumns([m.conversationId])
      ..where(m.accountId.equals(accountId) & m.isRead.equals(false) & existsQuery(inInbox));
  }
}

/// [ids] in lists SQLite's cap on bound variables accepts.
Iterable<List<String>> _chunks(Iterable<String> ids) sync* {
  final all = ids.toList();
  for (var i = 0; i < all.length; i += 500) {
    yield all.sublist(i, i + 500 > all.length ? all.length : i + 500);
  }
}
