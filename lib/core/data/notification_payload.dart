import 'dart:convert';

import '../domain/mail_notification.dart';
import '../domain/notification_action.dart';
import '../domain/notification_target.dart';

/// The payload of a notification: the ids of what it opens, never its content (#39). A Conversazione is
/// `[account, conversation]`, an Account's summary `[account]` (#210).
String encodePayload(NotificationTarget target) => jsonEncode(switch (target) {
  ConversationTarget(:final conversation) => [conversation.accountId, conversation.conversationId],
  AccountTarget(:final accountId) => [accountId],
});

/// What [payload] opens; null for anything [encodePayload] did not write.
NotificationTarget? decodePayload(String? payload) => switch (_decode(payload)) {
  [final String accountId, final String conversationId] => ConversationTarget((
    accountId: accountId,
    conversationId: conversationId,
  )),
  [final String accountId] => AccountTarget(accountId),
  _ => null,
};

/// The Azione of the button [actionId] (its [NotificationAction] name) of the notification of [payload]; null for a
/// tap on the notification itself, an unknown button, or one not on a Conversazione.
/// Also a [payload] of [encodeAction], whatever [actionId] says.
NotificationActionTap? decodeAction(String? payload, String? actionId) {
  if (_decode(payload) case [final String accountId, final String conversationId, final String name]) {
    return switch (_action(name)) {
      final action? => (conversation: (accountId: accountId, conversationId: conversationId), action: action),
      null => null,
    };
  }
  return switch ((decodePayload(payload), _action(actionId))) {
    (ConversationTarget(:final conversation), final action?) => (conversation: conversation, action: action),
    _ => null,
  };
}

/// A button that carries what it does, where the OS hands back one string for it (Windows' arguments):
/// `[account, conversation, action]`.
String encodeAction(NotificationActionTap tap) =>
    jsonEncode([tap.conversation.accountId, tap.conversation.conversationId, tap.action.name]);

NotificationAction? _action(String? name) => NotificationAction.values.asNameMap()[name];

Object? _decode(String? payload) {
  if (payload == null) return null;
  try {
    return jsonDecode(payload);
  } on FormatException catch (_) {
    return null;
  }
}

/// The notification id of [key], the same in every run (`Object.hash` is seeded per process): a newer message
/// replaces its Conversazione's notification also after a restart.
int notificationId(ConversationKey key) => _fnv('${key.accountId}\u0000${key.conversationId}');

/// The id of the summary «N nuovi messaggi» of [accountId]: a later summary replaces it.
int summaryId(String accountId) => _fnv('summary\u0000$accountId');

/// The id of the group notification of [accountId] (Android), titled with its address.
int groupId(String accountId) => _fnv('group\u0000$accountId');

/// The id of the notification of [target].
int idOf(NotificationTarget target) => switch (target) {
  ConversationTarget(:final conversation) => notificationId(conversation),
  AccountTarget(:final accountId) => summaryId(accountId),
};

/// 32-bit FNV-1a, kept to a positive 31-bit int.
int _fnv(String s) {
  var hash = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
