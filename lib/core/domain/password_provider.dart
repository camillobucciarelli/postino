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

/// Domains that connect with their own button (OAuth), never with a password: domain -> Provider. A custom domain
/// hosted at Outlook.com cannot be told from its address: it stays with the button.
const _oauthDomains = {
  'gmail.com': ProviderKind.gmail,
  'googlemail.com': ProviderKind.gmail,
  'outlook.com': ProviderKind.microsoft,
  'outlook.it': ProviderKind.microsoft,
  'hotmail.com': ProviderKind.microsoft,
  'hotmail.it': ProviderKind.microsoft,
  'live.com': ProviderKind.microsoft,
  'live.it': ProviderKind.microsoft,
  'msn.com': ProviderKind.microsoft,
};

/// The Provider whose own button [address] (already trimmed and lower case) connects with, or null when the
/// password form does: a Gmail or Microsoft address.
ProviderKind? oauthProviderFor(String address) => _oauthDomains[_domain(address)];

String _domain(String address) => address.substring(address.lastIndexOf('@') + 1);

/// Whether [servers] are Microsoft 365's (Exchange Online): it refuses the password login (`LOGINDISABLED`), the
/// address connects with «Collega Outlook». Told from the servers, never from the domain's MX.
bool microsoft365Servers(ServerSettings servers) => servers.imap.host.toLowerCase() == 'outlook.office365.com';

/// The Provider of the password Account [address] (already trimmed and lower case); null for an address of
/// [oauthProviderFor]. Any other domain is a generic IMAP server.
PasswordProvider? passwordProviderFor(String address) {
  if (oauthProviderFor(address) != null) return null;
  return _byDomain[_domain(address)] ?? const PasswordProvider(ProviderKind.imap);
}
