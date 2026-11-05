import 'package:equatable/equatable.dart';

import 'mail_action.dart';

/// An Azione done offline that met the same attribute changed elsewhere (ADR 0008): it stays open, the database
/// keeping the [local] version, until the user keeps it («tieni la mia») or [provider] («tieni quella del Provider»).
class const Conflict({
  /// L'Account del messaggio.
  required final String accountId,

  /// Provider-side id of the message.
  required final String messageId,

  /// The Azione the user did here: «tieni la mia» applies it again on the Provider.
  required final MailAction local,

  /// The value the Provider has for its attribute: a `bool`, or a [Placement].
  required final Object provider,
}) extends Equatable {
  /// Crea un Conflitto.
  this;

  @override
  List<Object?> get props => [accountId, messageId, local, provider];
}
