import 'dart:convert';

import '../domain/app_updater.dart';

/// The version file the release publishes (#287, tool/release/version_json.sh): `{"version": "X.Y.Z", "build": N,
/// "url": "https://…"}`, on iOS the app's App Store page (#323). The version in [body] if its build is above
/// [installed], null otherwise; throws [FormatException] on anything else. With [storeOnly] (iOS) a url that is not
/// https is the legacy TestFlight file (`itms-beta://`): no store page yet, so null, not an error.
AppUpdate? newerVersion(String body, {required int installed, bool storeOnly = false}) {
  if (jsonDecode(body) case {'version': final String version, 'build': final int build, 'url': final String url}
      when RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    final uri = Uri.parse(url);
    if (!uri.isScheme('https')) {
      if (storeOnly && uri.isScheme('itms-beta')) return null;
      throw const FormatException('url');
    }
    return build > installed ? (version: version, url: uri) : null;
  }
  throw const FormatException('version file');
}
