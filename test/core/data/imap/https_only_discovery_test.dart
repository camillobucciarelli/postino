import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/enough_server_discovery.dart';
import 'package:postino/core/data/imap/https_only_http_overrides.dart';
import 'package:postino/core/domain/mail_servers.dart';

const _xml = '''<?xml version="1.0"?>
<clientConfig version="1.1"><emailProvider id="example.org">
<domain>example.org</domain><displayName>Example</displayName>
<incomingServer type="imap"><hostname>imap.example.org</hostname><port>993</port><socketType>SSL</socketType>
<authentication>password-cleartext</authentication><username>%EMAILADDRESS%</username></incomingServer>
<outgoingServer type="smtp"><hostname>smtp.example.org</hostname><port>465</port><socketType>SSL</socketType>
<authentication>password-cleartext</authentication><username>%EMAILADDRESS%</username></outgoingServer>
</emailProvider></clientConfig>''';

const _expected = ServerSettings(
  imap: MailServer(host: 'imap.example.org', port: 993, security: ServerSecurity.ssl),
  smtp: MailServer(host: 'smtp.example.org', port: 465, security: ServerSecurity.ssl),
);

/// The DNS-over-HTTPS answer: example.org's mail goes to mx.mailhost.net.
final _mx = jsonEncode({
  'Status': 0,
  'Answer': [
    {'name': 'example.org.', 'type': 15, 'TTL': 300, 'data': '10 mx.mailhost.net.'},
  ],
});

/// The whole network of a test: every URL requested (including those dart:io would follow on its own) and the reply.
/// One instance for the file, reset per test: basic_utils keeps the first HTTP client it builds for good.
final _net = _FakeClient();

/// Members of the fakes nobody expected to be called; must stay empty, so a missing fake member fails the test
/// instead of turning into a quiet null discovery.
final _unexpected = <String>[];

Never _unimplemented(Invocation i) {
  _unexpected.add(i.memberName.toString());
  throw UnimplementedError('fake: ${i.memberName}');
}

class _FakeClient() implements HttpClient {
  final requests = <Uri>[];
  _Reply Function(Uri url) answer = (_) => _Reply(404);

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add(url);
    return _Request(this, url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => _unimplemented(invocation);
}

class _Reply(final int status, {final String body = '', final String? location}) {}

/// Like dart:io's request: with [followRedirects] on it opens the Location itself, without asking any HttpClient.
class _Request(final _FakeClient _net, final Uri _url) implements HttpClientRequest {
  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  final HttpHeaders headers = _Headers(null);

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async {
    var url = _url;
    var reply = _net.answer(url);
    for (var i = 0; followRedirects && reply.location != null && i < maxRedirects; i++) {
      url = url.resolve(reply.location!);
      _net.requests.add(url);
      reply = _net.answer(url);
    }
    return _Response(reply);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _unimplemented(invocation);
}

class _Response(final _Reply _reply) extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => _reply.status;

  @override
  String get reasonPhrase => '';

  @override
  int get contentLength => -1;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get isRedirect => _reply.location != null;

  @override
  HttpHeaders get headers => _Headers(_reply.location);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(_reply.body)).listen(onData, onError: onError, onDone: onDone);

  @override
  dynamic noSuchMethod(Invocation invocation) => _unimplemented(invocation);
}

class _Headers(final String? _location) implements HttpHeaders {
  @override
  String? value(String name) => name == HttpHeaders.locationHeader ? _location : null;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {
    if (_location != null) action(HttpHeaders.locationHeader, [_location]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _unimplemented(invocation);
}

/// Discovery with [answer] as the whole network (HTTP clients, raw sockets); returns the settings and the URLs asked.
Future<(ServerSettings?, List<Uri>)> _discover(_Reply Function(Uri url) answer) async {
  _net.answer = answer;
  final settings = await HttpOverrides.runWithHttpOverrides(
    () => IOOverrides.runZoned(
      () => EnoughServerDiscovery().discover('anna@example.org'),
      socketConnect: (host, port, {sourceAddress, sourcePort = 0, timeout}) =>
          Future.error(const SocketException('no network in tests')),
    ),
    _Overrides(),
  );
  return (settings, _net.requests);
}

class _Overrides() extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _net;
}

bool _isDns(Uri u) => u.host == 'dns.google.com';

void main() {
  setUp(() {
    _net.requests.clear();
    _net.answer = (_) => _Reply(404);
    _unexpected.clear();
  });
  tearDown(() => expect(_unexpected, isEmpty, reason: 'a fake was asked for a member it does not implement'));

  test('a valid HTTPS answer is used', () async {
    final (settings, requests) = await _discover(
      (url) => url.host == 'autoconfig.example.org' ? _Reply(200, body: _xml) : _Reply(404),
    );

    expect(settings, _expected);
    expect(requests.map((u) => u.scheme).toSet(), {'https'});
  });

  test('without autoconfig on the domain, the MX found over DNS-over-HTTPS leads to the ISP database', () async {
    final (settings, requests) = await _discover(
      (url) => switch (url.host) {
        'dns.google.com' => _Reply(200, body: _mx),
        'autoconfig.thunderbird.net' when url.path == '/v1.1/mailhost.net' => _Reply(200, body: _xml),
        _ => _Reply(404),
      },
    );

    expect(settings, _expected);
    expect(requests.map((u) => '${u.scheme}://${u.host}${u.path}'), [
      'https://autoconfig.example.org/mail/config-v1.1.xml',
      'https://dns.google.com/resolve',
      'https://autoconfig.mailhost.net/mail/config-v1.1.xml',
      'https://autoconfig.thunderbird.net/v1.1/example.org',
      'https://autoconfig.thunderbird.net/v1.1/mailhost.net',
    ]);
  });

  test('the autoconfig of the MX domain, found over DNS-over-HTTPS, is used', () async {
    final (settings, requests) = await _discover(
      (url) => switch (url.host) {
        'dns.google.com' => _Reply(200, body: _mx),
        'autoconfig.mailhost.net' => _Reply(200, body: _xml),
        _ => _Reply(404),
      },
    );

    expect(settings, _expected);
    expect(requests.where(_isDns), hasLength(1));
    expect(requests.where((u) => u.scheme != 'https'), isEmpty);
  });

  test('an invalid HTTPS answer ends without a result and no HTTP request leaves', () async {
    final (settings, requests) = await _discover((url) => _Reply(500));

    expect(settings, isNull);
    expect(requests.where(_isDns), isNotEmpty);
    expect(requests.where((u) => u.scheme != 'https'), isEmpty);
  });

  test('a failing HTTPS request does not fall back to HTTP', () async {
    final (settings, requests) = await _discover((url) => _Reply(200, body: 'not xml'));

    expect(settings, isNull);
    expect(requests.where((u) => u.scheme != 'https'), isEmpty);
  });

  test('a redirect to HTTP, from autoconfig or from the DNS lookup, is not followed', () async {
    final (settings, requests) = await _discover(
      (url) =>
          url.scheme == 'https' ? _Reply(302, location: 'http://${url.host}${url.path}?${url.query}') : _Reply(404),
    );

    expect(settings, isNull);
    expect(requests.where(_isDns), isNotEmpty);
    expect(requests.where((u) => u.scheme != 'https'), isEmpty);
  });

  test('openUrl (package:http, the DNS-over-HTTPS lookup) passes for https and refuses http', () async {
    final client = await HttpOverrides.runWithHttpOverrides(() => httpsOnly(() async => HttpClient()), _Overrides());

    await client.openUrl('GET', Uri.parse('https://dns.google.com/resolve?name=example.org&type=MX'));
    await expectLater(client.openUrl('GET', Uri.parse('http://example.org/')), throwsA(isA<HttpException>()));
    expect(_net.requests.map((u) => u.scheme), ['https']);
  });
}
