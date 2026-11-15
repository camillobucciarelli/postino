import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/result.dart';

/// The mail address of the signed-in user from Graph `/v1.0/me` with [accessToken] (`User.Read`): `mail`, the
/// primary SMTP address of a Microsoft 365 mailbox, else `userPrincipalName`. For an id_token without `email`, whose
/// `preferred_username` may be a work account's UPN instead of its address. Never throws: no network, or no answer
/// within 30 s, is [OfflineFailure].
Future<Result<String>> graphMeAddress(http.Client client, String accessToken) async {
  try {
    final r = await client
        .get(
          Uri.https('graph.microsoft.com', '/v1.0/me', {r'$select': 'mail,userPrincipalName'}),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        // Graph stalling would leave the consent pending with no message.
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) return Err(UnexpectedFailure('graph /me: HTTP ${r.statusCode}'));
    final me = jsonDecode(r.body) as Map<String, dynamic>;
    final address = me['mail'] ?? me['userPrincipalName'];
    return address is String ? Ok(address) : const Err(UnexpectedFailure('no address in graph /me'));
  } on http.ClientException {
    return const Err(OfflineFailure());
  } on TimeoutException {
    return const Err(OfflineFailure());
  } on Object catch (e, s) {
    return Err(UnexpectedFailure(e, s));
  }
}
