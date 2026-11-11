/// An app's OAuth client at a Provider: from `--dart-define`, never committed.
abstract interface class OAuthClient() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The client ID; empty when the build was not given one.
  String get id;

  /// Where codes and refresh tokens are exchanged for tokens.
  Uri get tokenEndpoint;

  /// What identifies the client in a token request.
  Map<String, String> get fields;
}
