import 'package:http/http.dart' as http;

import '../../domain/platform_services.dart';
import '../oauth/oauth_auth.dart';
import 'microsoft_client.dart';

/// The OAuth tokens of a Microsoft Account: refreshed on the common part, the new (rotated) refresh token
/// replacing the old one at every refresh. `invalid_grant` or a 401 is an `AuthFailure`: the Account is Da ricollegare.
OAuthAuth microsoftAuth(
  String accountId,
  SecureStore keychain,
  http.Client http_,
  Clock clock, {
  MicrosoftClient client = const MicrosoftClient.fromEnvironment(),
}) => OAuthAuth(accountId, keychain, http_, clock, client: client);
