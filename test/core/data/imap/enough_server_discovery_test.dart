import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/enough_server_discovery.dart';
import 'package:postino/core/domain/mail_servers.dart';

ServerConfig _server(ServerType type, String host, int port, SocketType socket) => ServerConfig(
  type: type,
  hostname: host,
  port: port,
  socketType: socket,
  authentication: Authentication.passwordClearText,
  usernameType: UsernameType.emailAddress,
);

ClientConfig _config({ServerConfig? imap, ServerConfig? smtp, bool insecure = false}) => ClientConfig(
  emailProviders: [
    ConfigEmailProvider()
      ..preferredIncomingImapServer = imap
      ..preferredOutgoingSmtpServer = smtp,
  ],
)..isFromInsecureSource = insecure;

void main() {
  final imap = _server(ServerType.imap, 'imap.example.org', 993, SocketType.ssl);
  final smtp = _server(ServerType.smtp, 'smtp.example.org', 587, SocketType.plain);

  test('maps the discovered servers; a plain one upgrades with STARTTLS', () {
    expect(
      discoveredServers(_config(imap: imap, smtp: smtp)),
      const ServerSettings(
        imap: MailServer(host: 'imap.example.org', port: 993, security: ServerSecurity.ssl),
        smtp: MailServer(host: 'smtp.example.org', port: 587, security: ServerSecurity.starttls),
      ),
    );
  });

  test('an unknown socket type is SSL on 993 and 465 only', () {
    final s = discoveredServers(
      _config(
        imap: _server(ServerType.imap, 'i', 143, SocketType.unknown),
        smtp: _server(ServerType.smtp, 's', 465, SocketType.unknown),
      ),
    );
    expect(s?.imap.security, ServerSecurity.starttls);
    expect(s?.smtp.security, ServerSecurity.ssl);
  });

  test('a config from plain HTTP, or missing a server, is not used', () {
    expect(discoveredServers(_config(imap: imap, smtp: smtp, insecure: true)), isNull);
    expect(discoveredServers(_config(imap: imap)), isNull);
    expect(discoveredServers(null), isNull);
  });
}
