import 'dart:io';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Opens [url] in the system browser and returns the callback URL.
typedef Authenticate = Future<String> Function({required String url, required String callbackUrlScheme});

/// The real [Authenticate]: the system browser, never an embedded webview (Google refuses consent in those).
Future<String> systemBrowser({required String url, required String callbackUrlScheme}) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackUrlScheme,
  options: const FlutterWebAuth2Options(useWebview: false),
);

/// Windows/Linux have no app callback scheme: a public client redirects to localhost.
bool get loopbackRedirectPlatform => Platform.isWindows || Platform.isLinux;

// ponytail: fixed loopback port; pick a free one if it ever clashes.
const loopbackRedirect = 'http://localhost:53682';
