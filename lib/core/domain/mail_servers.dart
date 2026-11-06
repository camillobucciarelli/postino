import 'package:equatable/equatable.dart';

/// How the connection to a mail server is encrypted. Only encrypted connections: no plain text.
enum ServerSecurity() {
  /// TLS from the first byte (IMAP 993, SMTP 465).
  ssl,

  /// Plain connection upgraded with STARTTLS before the login (IMAP 143, SMTP 587).
  starttls,
}

/// One mail server: where it is and how the connection is encrypted.
class const MailServer({
  /// Nome dell'host, per esempio `imap.mail.me.com`.
  required final String host,

  /// Porta TCP.
  required final int port,

  /// Cifratura della connessione.
  required final ServerSecurity security,
}) extends Equatable {
  /// Crea il server.
  this;

  @override
  List<Object?> get props => [host, port, security];
}

/// The servers of a password Account: IMAP to read, SMTP to send. The user name is always the full address.
class const ServerSettings({
  /// Server IMAP, per leggere.
  required final MailServer imap,

  /// Server SMTP, per inviare.
  required final MailServer smtp,
}) extends Equatable {
  /// Crea le impostazioni dei server.
  this;

  @override
  List<Object?> get props => [imap, smtp];
}
