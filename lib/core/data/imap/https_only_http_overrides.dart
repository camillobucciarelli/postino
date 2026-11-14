import 'dart:io';

/// Runs [body] with every `HttpClient` created in it refusing plain `http://` requests (they fail like an
/// unreachable server). enough_mail's autodiscovery retries over HTTP with the full address in the URL when HTTPS
/// fails; here that retry never leaves the device.
Future<T> httpsOnly<T>(Future<T> Function() body) => HttpOverrides.runWithHttpOverrides(body, _HttpsOnlyOverrides());

class _HttpsOnlyOverrides() extends HttpOverrides {
  // The client the zone would have built without us (a test's fake, or the real one).
  final HttpOverrides? _outer = HttpOverrides.current;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _HttpsOnlyClient(_outer?.createHttpClient(context) ?? super.createHttpClient(context));
}

// ponytail: only what enough_mail's HttpHelper and package:http call is forwarded; any other member (open, get, ...) throws, so a
// future caller fails closed instead of bypassing the check.
class _HttpsOnlyClient(final HttpClient _inner) implements HttpClient {
  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  // package:http (the DNS-over-HTTPS lookup of basic_utils) goes through here.
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      url.scheme == 'https' ? _inner.openUrl(method, url) : Future.error(HttpException('Plain HTTP refused', uri: url));

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
