/// The app's Google OAuth client, from `--dart-define`: it is never committed.
class GoogleClient {
  const GoogleClient(this.id, [this.secret = '']);

  const GoogleClient.fromEnvironment()
    : id = const String.fromEnvironment('GOOGLE_CLIENT_ID'),
      secret = const String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  final String id;

  /// Only "Desktop app" clients (Windows/Linux loopback) have one; Google does not treat it as secret.
  final String secret;

  Map<String, String> get fields => {'client_id': id, if (secret.isNotEmpty) 'client_secret': secret};
}
