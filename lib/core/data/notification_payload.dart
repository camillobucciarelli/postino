import 'dart:convert';

import '../domain/mail_notification.dart';

/// The payload of a notification: the ids of its Conversazione, never its content (#39).
String encodePayload(ConversationKey key) => jsonEncode([key.accountId, key.conversationId]);

/// The Conversazione of [payload]; null for anything [encodePayload] did not write.
ConversationKey? decodePayload(String? payload) {
  if (payload == null) return null;
  try {
    if (jsonDecode(payload) case [final String accountId, final String conversationId]) {
      return (accountId: accountId, conversationId: conversationId);
    }
  } on FormatException catch (_) {}
  return null;
}

/// The notification id of [key], the same in every run (`Object.hash` is seeded per process): a newer message
/// replaces its Conversazione's notification also after a restart. 32-bit FNV-1a, kept to a positive 31-bit int.
int notificationId(ConversationKey key) {
  var hash = 0x811c9dc5;
  for (final unit in '${key.accountId}\u0000${key.conversationId}'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
