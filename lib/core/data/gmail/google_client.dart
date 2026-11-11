import '../oauth/oauth_client.dart';

/// The app's Google OAuth client, from `--dart-define`: it is never committed.
class GoogleClient implements OAuthClient {
  const GoogleClient(this.id, [this.secret = '']);

  const GoogleClient.fromEnvironment()
    : id = const String.fromEnvironment('GOOGLE_CLIENT_ID'),
      secret = const String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  @override
  final String id;

  /// Only "Desktop app" clients (Windows/Linux loopback) have one; Google does not treat it as secret.
  final String secret;

  @override
  Uri get tokenEndpoint => Uri.parse('https://oauth2.googleapis.com/token');

  @override
  Map<String, String> get fields => {'client_id': id, if (secret.isNotEmpty) 'client_secret': secret};
}
