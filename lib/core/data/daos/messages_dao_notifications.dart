import 'package:drift/drift.dart';

import '../../domain/message.dart';
import 'messages_dao.dart';

/// What the notifications' cleanup asks of the cached messages (#238): which messages are still unread in the inbox.
extension MessagesDaoNotifications on MessagesDao {
  /// Of [messageIds], those in cache still unread and in the inbox.
  Future<Set<String>> unreadInInbox(String accountId, Iterable<String> messageIds) async {
    final m = messages;
    final l = messageLabels;
    final inInbox = selectOnly(l)
      ..addColumns([l.messageId])
      ..where(l.accountId.equalsExp(m.accountId) & l.messageId.equalsExp(m.id) & l.labelId.equals(inboxLabelId));
    return {
      for (final chunk in _chunks(messageIds))
        ...await (selectOnly(m)
              ..addColumns([m.id])
              ..where(m.accountId.equals(accountId) & m.id.isIn(chunk) & m.isRead.equals(false) & existsQuery(inInbox)))
            .map((r) => r.read(m.id)!)
            .get(),
    };
  }

  /// The messages of the Conversazione [conversationId] in cache.
  Future<Set<String>> messagesOf(String accountId, String conversationId) async => {
    ...await (selectOnly(messages)
          ..addColumns([messages.id])
          ..where(messages.accountId.equals(accountId) & messages.conversationId.equals(conversationId)))
        .map((r) => r.read(messages.id)!)
        .get(),
  };
}

/// [ids] in lists SQLite's cap on bound variables accepts.
Iterable<List<String>> _chunks(Iterable<String> ids) sync* {
  final all = ids.toList();
  for (var i = 0; i < all.length; i += 500) {
    yield all.sublist(i, i + 500 > all.length ? all.length : i + 500);
  }
}
