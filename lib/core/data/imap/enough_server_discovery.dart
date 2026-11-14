import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/mail_servers.dart';
import '../../domain/server_discovery.dart';
import 'https_only_http_overrides.dart';

/// Autodiscovery with enough_mail's `Discover.discover`, HTTPS only: `autoconfig.<domain>` (and that of the MX domain),
/// MX lookup over Google DNS-over-HTTPS, Mozilla's ISP database, then guessed host names (sockets, no credentials).
/// The package's plain-HTTP retry with the address in the URL is blocked.
@LazySingleton(as: ServerDiscovery, env: [Environment.prod])
class EnoughServerDiscovery() implements ServerDiscovery {
  @override
  Future<ServerSettings?> discover(String address) async {
    try {
      return discoveredServers(await httpsOnly(() => Discover.discover(address)));
    } on Object {
      return null;
    }
  }
}

/// The servers of a discovered [config]; null when it lacks one, or came over plain HTTP: whoever answered there
/// could point the password to their own host, so the user enters the servers by hand.
@visibleForTesting
ServerSettings? discoveredServers(ClientConfig? config) {
  if (config == null || config.isFromInsecureSource) return null;
  final imap = _server(config.preferredIncomingImapServer);
  final smtp = _server(config.preferredOutgoingSmtpServer);
  if (imap == null || smtp == null) return null;
  return ServerSettings(imap: imap, smtp: smtp);
}

/// A discovered server; a plain-text one is asked to upgrade with STARTTLS, since Postino never sends the password
/// in clear (the test connection fails if the server cannot).
// ponytail: the user name is always the full address; honour ServerConfig.usernameType if a server wants the local part.
MailServer? _server(ServerConfig? s) {
  if (s == null || s.hostname.isEmpty || s.port <= 0) return null;
  final ssl =
      s.socketType == SocketType.ssl || (s.socketType == SocketType.unknown && (s.port == 993 || s.port == 465));
  return MailServer(host: s.hostname, port: s.port, security: ssl ? ServerSecurity.ssl : ServerSecurity.starttls);
}
