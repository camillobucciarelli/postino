import 'dart:convert';

import '../../domain/mail_servers.dart';
import '../../domain/platform_services.dart';

/// Password and servers of an iCloud or IMAP Account: they live only in the keychain, never in the database nor
/// in the log (like OAuthTokens). The user name is the Account's address. Between devices they travel only inside
/// the sealed file of the Impostazioni, in the voce `credentials/<accountId>` (ADR 0019).
class const PasswordCredentials({required final String password, required final ServerSettings servers}) {
  /// The keychain item of [accountId]: its value is [encode]'s text, the same as the synced voce's.
  static String keychainKey(String accountId) => 'password:$accountId';

  static Future<PasswordCredentials?> read(SecureStore keychain, String accountId) async {
    final raw = await keychain.read(keychainKey(accountId));
    return raw == null ? null : decode(raw);
  }

  /// The credentials [encode] wrote; throws on anything else. Its errors may quote [raw]: never log them.
  static PasswordCredentials decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return PasswordCredentials(
      password: j['password'] as String,
      servers: ServerSettings(imap: _server(j['imap']), smtp: _server(j['smtp'])),
    );
  }

  /// Forgets the password and servers of [accountId]: the Account was removed.
  static Future<void> delete(SecureStore keychain, String accountId) => keychain.delete(keychainKey(accountId));

  Future<void> write(SecureStore keychain, String accountId) => keychain.write(keychainKey(accountId), encode());

  /// `{"password":"…","imap":{…},"smtp":{…}}`, as the keychain and the synced voce keep it.
  String encode() => jsonEncode({'password': password, 'imap': _json(servers.imap), 'smtp': _json(servers.smtp)});

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
