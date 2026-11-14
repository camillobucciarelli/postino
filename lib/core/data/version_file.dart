import 'dart:convert';

import '../domain/app_updater.dart';

/// The version file the release publishes (#287, tool/release/version_json.sh): `{"version": "X.Y.Z", "build": N,
/// "url": "https://…" or "itms-beta://"}`. The version in [body] if its build is above [installed], null otherwise;
/// throws [FormatException] on anything else.
AppUpdate? newerVersion(String body, {required int installed}) {
  if (jsonDecode(body) case {'version': final String version, 'build': final int build, 'url': final String url}
      when RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    final uri = Uri.parse(url);
    if (!uri.isScheme('https') && !uri.isScheme('itms-beta')) throw const FormatException('url');
    return build > installed ? (version: version, url: uri) : null;
  }
  throw const FormatException('version file');
}
