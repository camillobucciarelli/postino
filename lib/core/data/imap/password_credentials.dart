import 'dart:convert';

import '../../domain/mail_servers.dart';
import '../../domain/platform_services.dart';

/// Password and servers of an iCloud or IMAP Account: they live only in the keychain, never in the database nor
/// in the log (like GmailTokens). The user name is the Account's address.
class const PasswordCredentials({required final String password, required final ServerSettings servers}) {
  static String _key(String accountId) => 'password:$accountId';

  static Future<PasswordCredentials?> read(SecureStore keychain, String accountId) async {
    final raw = await keychain.read(_key(accountId));
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return PasswordCredentials(
      password: j['password'] as String,
      servers: ServerSettings(imap: _server(j['imap']), smtp: _server(j['smtp'])),
    );
  }

  Future<void> write(SecureStore keychain, String accountId) => keychain.write(
    _key(accountId),
    jsonEncode({'password': password, 'imap': _json(servers.imap), 'smtp': _json(servers.smtp)}),
  );

  static Map<String, Object> _json(MailServer s) => {'host': s.host, 'port': s.port, 'security': s.security.name};

  static MailServer _server(Object? raw) {
    final j = raw as Map<String, dynamic>;
    return MailServer(
      host: j['host'] as String,
      port: j['port'] as int,
      security: ServerSecurity.values.byName(j['security'] as String),
    );
  }
}
