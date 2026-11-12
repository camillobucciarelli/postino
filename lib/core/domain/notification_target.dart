import 'package:equatable/equatable.dart';

import 'mail_notification.dart';

/// What a notification opens (#210): a Conversazione, or the inbox of an Account for its summary.
sealed class const NotificationTarget() extends Equatable {
  /// Costruttore delle varianti.
  this;

  /// The Account the notification belongs to: its group.
  String get accountId;
}

/// The notification of a Conversazione: a tap opens it over the Posta unificata.
final class const ConversationTarget(
  /// La Conversazione.
  final ConversationKey conversation,
) extends NotificationTarget {
  /// Crea la destinazione.
  this;

  @override
  String get accountId => conversation.accountId;

  @override
  List<Object?> get props => [conversation];
}

/// The summary «N nuovi messaggi» of an Account: a tap opens its inbox.
final class const AccountTarget(@override final String accountId) extends NotificationTarget {
  /// Crea la destinazione.
  this;

  @override
  List<Object?> get props => [accountId];
}
