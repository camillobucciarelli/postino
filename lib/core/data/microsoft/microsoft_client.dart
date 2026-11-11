import '../oauth/oauth_client.dart';

/// The app's Microsoft OAuth client (personal accounts only), from `--dart-define`: it is never committed.
/// A public client: no secret.
class MicrosoftClient implements OAuthClient {
  const MicrosoftClient(this.id);

  const MicrosoftClient.fromEnvironment() : id = const String.fromEnvironment('MICROSOFT_CLIENT_ID');

  @override
  final String id;

  /// The `consumers` endpoint of the Microsoft identity platform: no work or school tenants (v1).
  static final authorizeEndpoint = Uri.https('login.microsoftonline.com', '/consumers/oauth2/v2.0/authorize');

  @override
  Uri get tokenEndpoint => Uri.https('login.microsoftonline.com', '/consumers/oauth2/v2.0/token');

  @override
  Map<String, String> get fields => {'client_id': id};
}
