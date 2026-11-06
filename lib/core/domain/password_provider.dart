import 'account.dart';
import 'mail_servers.dart';

/// What the address of a password Account says about its Provider: the [kind] and, when known, the [preset] servers.
class const PasswordProvider(
  /// Il Provider dell'Account.
  final ProviderKind kind, [

  /// Server noti in anticipo; null quando vanno scoperti (autodiscovery) o inseriti a mano.
  final ServerSettings? preset,
]) {
  /// Crea il Provider.
  this;
}

/// iCloud Mail (docs/research/invio-posta-per-provider.md §3): the same app-specific password for IMAP and SMTP.
const icloudServers = ServerSettings(
  imap: MailServer(host: 'imap.mail.me.com', port: 993, security: ServerSecurity.ssl),
  smtp: MailServer(host: 'smtp.mail.me.com', port: 587, security: ServerSecurity.starttls),
);

/// The Provider-specific choices for password Accounts, in one place (OCP): domain -> Provider.
const _byDomain = {
  'icloud.com': PasswordProvider(ProviderKind.icloud, icloudServers),
  'me.com': PasswordProvider(ProviderKind.icloud, icloudServers),
  'mac.com': PasswordProvider(ProviderKind.icloud, icloudServers),
};

/// Domains that connect with their own button (OAuth), never with a password.
const _oauthDomains = {'gmail.com', 'googlemail.com'};

/// The Provider of the password Account [address] (already trimmed and lower case); null for a Gmail address,
/// which connects with «Collega Gmail». Any other domain is a generic IMAP server.
PasswordProvider? passwordProviderFor(String address) {
  final domain = address.substring(address.lastIndexOf('@') + 1);
  if (_oauthDomains.contains(domain)) return null;
  return _byDomain[domain] ?? const PasswordProvider(ProviderKind.imap);
}
