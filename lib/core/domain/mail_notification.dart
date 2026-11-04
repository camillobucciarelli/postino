import 'package:equatable/equatable.dart';

/// A Conversazione of an Account: what a notification opens.
typedef ConversationKey = ({String accountId, String conversationId});

/// The notification of a new message (#39): who sent it, its subject and preview; tapping it opens [conversation].
class const MailNotification({
  /// The Conversazione the message belongs to.
  required final ConversationKey conversation,

  /// The sender's display name, or its address without one.
  required final String sender,

  /// Oggetto.
  required final String subject,

  /// Anteprima del testo.
  required final String preview,
}) extends Equatable {
  /// Crea una notifica.
  this;

  @override
  List<Object?> get props => [conversation, sender, subject, preview];
}
