// Microsoft Graph answering with the responses of test/fixtures/graph: no network.
// ponytail: the fixtures follow the shapes Graph documents, with fake ids and addresses; replace them with the
// responses of the Outlook.com test Account (cleaned of real addresses and tokens) once it records them.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/microsoft/microsoft_client.dart';
import 'package:postino/core/data/microsoft/microsoft_provider.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';

import 'fake_platform.dart';

const graphAccount = 'microsoft:ada@outlook.com';
final graphNow = DateTime.utc(2026, 10, 28, 12);
const graphTestClient = MicrosoftClient('00000000-test-0000-0000-000000000000');
const graphApi = '/v1.0/me/';
const tokenHost = 'login.microsoftonline.com';

/// The Graph id of a fixture folder (`inbox`, `viaggi`...) and of a fixture message (`f1`...).
String folderId(String key) => 'AQMkADAwATZiZmYAZS0yNgAuAAADm-$key';
String messageIdOf(String key) => 'AAkALgAAAAAAHYQDEapmEc2byACqAC-EWg0AWLuF-$key';

/// The recorded response `test/fixtures/graph/<name>.json`; `{folder}` in it becomes [folder]. Header names are
/// lowercased, as package:http gives them.
http.Response graphFixture(String name, {String folder = ''}) {
  final raw = File('test/fixtures/graph/$name.json').readAsStringSync().replaceAll('{folder}', folder);
  final j = jsonDecode(raw) as Map<String, dynamic>;
  final headers = {
    for (final MapEntry(:key, :value) in (j['headers'] as Map? ?? const {}).entries) '$key'.toLowerCase(): '$value',
  };
  return graphJson(j['body'] as Object, j['status'] as int, headers);
}

http.Response graphJson(Object body, [int status = 200, Map<String, String> headers = const {}]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8', ...headers});

/// A keychain holding [graphAccount]'s tokens.
FakeSecureStore graphKeychain({String access = 'EwB.initial', Duration validFor = const Duration(hours: 1)}) {
  final keychain = FakeSecureStore();
  // FakeSecureStore writes synchronously.
  unawaited(
    OAuthTokens(
      access: access,
      refresh: 'M.C5.initial',
      expiresAt: graphNow.add(validFor),
    ).write(keychain, graphAccount),
  );
  return keychain;
}

/// The path of a Graph request under `/v1.0/me/`, the folder id unquoted: `mailFolders('x')` is `mailFolders/x`.
String graphPath(http.Request r) =>
    r.url.path.substring(graphApi.length).replaceAllMapped(RegExp(r"\('([^']*)'\)"), (m) => '/${m[1]}');

/// Graph answering each request with the recorded response `route` gives; the token endpoint refreshes.
class RecordedGraph(http.Response Function(http.Request r, String path) route) {
  this {
    provider = MicrosoftProvider(
      graphAccount,
      graphKeychain(),
      MockClient((r) async {
        requests.add(r);
        if (r.url.host == tokenHost) return graphFixture('token_refresh');
        return route(r, graphPath(r));
      }),
      FakeClock(graphNow),
      client: graphTestClient,
      sleep: (d) async => sleeps.add(d),
    );
  }

  late final MicrosoftProvider provider;
  final requests = <http.Request>[];
  final sleeps = <Duration>[];

  Iterable<Uri> get urls => requests.map((r) => r.url);
}
