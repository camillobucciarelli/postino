import '../oauth/oauth_client.dart';

/// The app's Microsoft OAuth client (personal, work and school accounts), from `--dart-define`: it is never committed.
/// A public client: no secret.
class MicrosoftClient implements OAuthClient {
  const MicrosoftClient(this.id);

  const MicrosoftClient.fromEnvironment() : id = const String.fromEnvironment('MICROSOFT_CLIENT_ID');

  @override
  final String id;

  /// The `common` endpoint of the Microsoft identity platform: personal accounts and work or school ones (Microsoft 365).
  static final authorizeEndpoint = Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/authorize');

  @override
  Uri get tokenEndpoint => Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/token');

  @override
  Map<String, String> get fields => {'client_id': id};
}
