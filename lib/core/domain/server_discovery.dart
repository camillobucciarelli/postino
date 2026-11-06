import 'mail_servers.dart';

/// Finds the servers of an address (autodiscovery, RFC 6186 and autoconfig). The real one in core/data.
abstract interface class ServerDiscovery() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The IMAP and SMTP servers of [address]; null when none are found. Never throws.
  Future<ServerSettings?> discover(String address);
}
