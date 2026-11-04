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
