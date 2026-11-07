import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import '../../domain/platform_services.dart';

/// Revokes a Google refresh token when its Account is removed (#174), best effort: offline it is not sent, and a
/// failure is ignored. The Account goes anyway; the grant then stays listed in the user's Google account.
@lazySingleton
class GoogleRevoke(final http.Client _http, final Connectivity _connectivity) {
  static final _endpoint = Uri.parse('https://oauth2.googleapis.com/revoke');

  Future<void> revoke(String token) async {
    if (!_connectivity.isOnline) return;
    try {
      await _http.post(_endpoint, body: {'token': token}).timeout(const Duration(seconds: 10));
    } on Object catch (e) {
      debugPrint('[accounts] token revocation failed, ${e.runtimeType}');
    }
  }
}
