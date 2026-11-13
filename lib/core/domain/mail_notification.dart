import 'package:equatable/equatable.dart';

import 'notification_action.dart';

/// A Conversazione of an Account: what a notification opens.
typedef ConversationKey = ({String accountId, String conversationId});

/// The notification of a new message (#39), one per message (#238): who sent it, its subject and preview; tapping it
/// opens [conversation].
class const MailNotification({
  /// The Conversazione the message belongs to.
  required final ConversationKey conversation,

  /// The message: its own notification.
  required final String messageId,

  /// The address of its Account: the title of the Account's group (#210).
  required final String accountAddress,

  /// The sender's display name, or its address without one.
  required final String sender,

  /// Oggetto.
  required final String subject,

  /// Anteprima del testo.
  required final String preview,

  /// Its buttons, in order (#211): the Azioni delle notifiche.
  final List<NotificationAction> actions = const [],
}) extends Equatable {
  /// Crea una notifica.
  this;

  @override
  List<Object?> get props => [conversation, messageId, accountAddress, sender, subject, preview, actions];
}
