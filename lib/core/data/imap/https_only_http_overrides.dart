import 'dart:io';

/// Runs [body] with every `HttpClient` created in it refusing plain `http://` requests (they fail like an
/// unreachable server) and never following a redirect on its own. enough_mail's autodiscovery retries over HTTP with
/// the full address in the URL when HTTPS fails; here that retry never leaves the device.
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
  Future<HttpClientRequest> openUrl(String method, Uri url) => url.scheme == 'https'
      ? _inner.openUrl(method, url).then((r) => _NoRedirectRequest(r..followRedirects = false))
      : Future.error(HttpException('Plain HTTP refused', uri: url));

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A request that never follows redirects: dart:io would open the Location on its own client, past the scheme check
/// above. enough_mail follows its redirects itself, each through getUrl (so checked); package:http (the DNS lookup)
/// would ask dart:io to, so it gets the 3xx as is and the lookup fails. dns.google.com answers without redirects.
// ponytail: only what HttpHelper and IOClient call is forwarded, the rest throws (fails closed).
class _NoRedirectRequest(final HttpClientRequest _inner) implements HttpClientRequest {
  @override
  bool get followRedirects => false;

  @override
  set followRedirects(bool _) {}

  @override
  int get maxRedirects => _inner.maxRedirects;

  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  int get contentLength => _inner.contentLength;

  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  Future<HttpClientResponse> close() => _inner.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
