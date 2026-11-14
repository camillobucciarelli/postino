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

/// Answers every request through [answer]; no network. Records the URLs it was asked.
class _FakeClient(final List<Uri> requests, final _Reply Function(Uri url) answer) implements HttpClient {
  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add(url);
    return _Request(answer(url));
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reply(final int status, {final String body = '', final String? location}) {}

class _Request(final _Reply _reply) implements HttpClientRequest {
  @override
  bool followRedirects = true;

  @override
  Future<HttpClientResponse> close() async => _Response(_reply);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response(final _Reply _reply) extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => _reply.status;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers(final String? _location) implements HttpHeaders {
  @override
  String? value(String name) => name == HttpHeaders.locationHeader ? _location : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Discovery with [answer] as the whole network (HTTP clients, raw sockets); returns the settings and the URLs asked.
Future<(ServerSettings?, List<Uri>)> _discover(_Reply Function(Uri url) answer) async {
  final requests = <Uri>[];
  final settings = await HttpOverrides.runWithHttpOverrides(
    () => IOOverrides.runZoned(
      () => EnoughServerDiscovery().discover('anna@example.org'),
      socketConnect: (host, port, {sourceAddress, sourcePort = 0, timeout}) =>
          Future.error(const SocketException('no network in tests')),
    ),
    _Overrides(_FakeClient(requests, answer)),
  );
  return (settings, requests);
}

class _Overrides(final HttpClient _client) extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _client;
}

void main() {
  test('a valid HTTPS answer is used', () async {
    final (settings, requests) = await _discover(
      (url) => url.host == 'autoconfig.example.org' ? _Reply(200, body: _xml) : _Reply(404),
    );

    expect(
      settings,
      const ServerSettings(
        imap: MailServer(host: 'imap.example.org', port: 993, security: ServerSecurity.ssl),
        smtp: MailServer(host: 'smtp.example.org', port: 465, security: ServerSecurity.ssl),
      ),
    );
    expect(requests.map((u) => u.scheme).toSet(), {'https'});
  });

  test('an invalid HTTPS answer ends without a result and no HTTP request leaves', () async {
    final (settings, requests) = await _discover((url) => _Reply(500));

    expect(settings, isNull);
    expect(requests, isNotEmpty);
    expect(requests.where((u) => u.scheme != 'https'), isEmpty);
  });

  test('a failing HTTPS request does not fall back to HTTP', () async {
    final (settings, requests) = await _discover((url) => _Reply(200, body: 'not xml'));

    expect(settings, isNull);
    expect(requests.where((u) => u.scheme != 'https'), isEmpty);
  });

  test('a redirect to HTTP is not followed', () async {
    final (settings, requests) = await _discover(
      (url) =>
          _Reply(302, location: 'http://autoconfig.example.org/mail/config-v1.1.xml?emailaddress=anna@example.org'),
    );

    expect(settings, isNull);
    expect(requests.where((u) => u.scheme != 'https'), isEmpty);
  });

  test('openUrl (package:http, the DNS-over-HTTPS lookup) passes for https and refuses http', () async {
    final requests = <Uri>[];
    final client = await HttpOverrides.runWithHttpOverrides(
      () => httpsOnly(() async => HttpClient()),
      _Overrides(_FakeClient(requests, (url) => _Reply(200))),
    );

    await client.openUrl('GET', Uri.parse('https://dns.google.com/resolve?name=example.org&type=MX'));
    await expectLater(client.openUrl('GET', Uri.parse('http://example.org/')), throwsA(isA<HttpException>()));
    expect(requests.map((u) => u.scheme), ['https']);
  });
}
