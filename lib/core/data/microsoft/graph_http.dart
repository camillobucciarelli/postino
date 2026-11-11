import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../json_objects.dart';
import '../oauth/oauth_auth.dart';
import '../oauth/oauth_failed.dart';
import 'graph_failure.dart';
import 'microsoft_auth.dart';
import 'microsoft_client.dart';

/// Microsoft Graph over HTTP for one Account (`/v1.0/me/...`): tokens from [microsoftAuth], refreshed when expired
/// and once more on a 401; a throttled request waits its `Retry-After` and is tried once more; at most
/// [maxConcurrent] requests at a time, Outlook's limit per mailbox. Failures are thrown as [OAuthFailed].
class GraphHttp(
  String accountId,
  SecureStore keychain,
  final http.Client _http,
  final Clock _clock, {
  MicrosoftClient client = const MicrosoftClient.fromEnvironment(),
  final Future<void> Function(Duration) _sleep = Future<void>.delayed,

  /// The longest wait for an answer to start, and between two of its chunks.
  final Duration _timeout = const Duration(seconds: 30),
}) {
  this : _auth = microsoftAuth(accountId, keychain, _http, _clock, client: client);

  static const host = 'graph.microsoft.com';
  static final _api = Uri.https(host, '/v1.0/me/');

  /// Outlook serves at most 4 concurrent requests per mailbox.
  static const maxConcurrent = 4;

  /// Immutable ids: a message keeps its id when it moves to another folder. Pages of 100 items.
  static const prefer = 'IdType="ImmutableId", odata.maxpagesize=100';

  /// The wait of a throttled request without `Retry-After`, and the longest one honoured.
  static const _defaultWait = Duration(seconds: 5);
  static const _maxWait = Duration(seconds: 60);

  final OAuthAuth _auth;
  var _running = 0;
  final _waiting = Queue<Completer<void>>();

  /// Refreshes the access token now; a revoked refresh token is [AuthFailure].
  Future<void> refreshAuth() async {
    await _auth.refresh(await _auth.tokens());
  }

  /// GET [path] (under `/v1.0/me/`) with [query]; [prefer] adds preferences to [GraphHttp.prefer].
  Future<Map<String, dynamic>> get(String path, {Map<String, String> query = const {}, String? prefer}) =>
      _request('GET', _api.resolve(path).replace(queryParameters: query.isEmpty ? null : query), prefer: prefer);

  /// GET of the raw bytes at [path] (an attachment's `$value`), read as they arrive: [onProgress] gets the share
  /// read out of `Content-Length`, and completing [cancel] aborts the request (`http.RequestAbortedException`).
  Future<Uint8List> getBytes(String path, {void Function(double done)? onProgress, Future<void>? cancel}) async =>
      (await _response('GET', _api.resolve(path), onProgress: onProgress, cancel: cancel)).bodyBytes;

  /// GET of a `@odata.nextLink` or `@odata.deltaLink`. Only Graph's own links: the token goes to no other host,
  /// and a link that is not one (a tampered cursor) is [NotFoundFailure].
  Future<Map<String, dynamic>> follow(String link) {
    final url = Uri.tryParse(link);
    if (url == null || url.scheme != 'https' || url.host != host) throw const OAuthFailed(NotFoundFailure());
    return _request('GET', url);
  }

  /// A write: [method] on [path], [body] as JSON.
  Future<Map<String, dynamic>> send(String method, String path, {Object? body}) =>
      _request(method, _api.resolve(path), body: body);

  /// Every item of the collection [path], following `@odata.nextLink`.
  Future<List<Map<String, dynamic>>> list(String path, {Map<String, String> query = const {}}) async {
    final items = <Map<String, dynamic>>[];
    for (var page = await get(path, query: query); ; page = await follow(page['@odata.nextLink'] as String)) {
      items.addAll(jsonObjects(page['value']));
      if (page['@odata.nextLink'] == null) return items;
    }
  }

  Future<Map<String, dynamic>> _request(String method, Uri url, {Object? body, String? prefer}) async {
    final r = await _response(method, url, body: body, prefer: prefer);
    // A 204 (a DELETE) has no body.
    return r.body.isEmpty ? const {} : jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<http.Response> _response(
    String method,
    Uri url, {
    Object? body,
    String? prefer,
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final payload = body == null ? null : jsonEncode(body);
    Future<http.Response> send(String token) =>
        _slot(() => _send(method, url, token, payload, prefer, onProgress, cancel));

    var r = await _auth.authorized(send);
    if (graphThrottled(r)) {
      await _sleep(_retryAfter(r) ?? _defaultWait);
      // Authorized again: the token may have expired during the wait.
      r = await _auth.authorized(send);
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return r;
    // Never the Authorization header nor the query: method, path and status only.
    if (graphThrottled(r)) debugPrint('[graph] throttled: $method ${url.path} ${r.statusCode}');
    final wait = _retryAfter(r);
    throw OAuthFailed(graphFailure(r, url.path, retryAfter: wait == null ? null : _clock.now().add(wait)));
  }

  /// One try; a timeout aborts the connection too, before its slot goes to the next request.
  Future<http.Response> _send(
    String method,
    Uri url,
    String access,
    String? payload,
    String? extraPrefer,
    void Function(double done)? onProgress,
    Future<void>? cancel,
  ) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            method,
            url,
            abortTrigger: cancel == null ? abort.future : Future.any([cancel, abort.future]),
          )
          ..headers['authorization'] = 'Bearer $access'
          ..headers['prefer'] = extraPrefer == null ? prefer : '$prefer, $extraPrefer';
    if (payload != null) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = payload;
    }
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      final total = streamed.contentLength ?? 0;
      var read = 0;
      // At most [_timeout] between two chunks: a long download is fine, a stalled one is not.
      final bytes = await http.ByteStream(
        streamed.stream.timeout(_timeout).map((chunk) {
          read += chunk.length;
          if (total > 0) onProgress?.call(min(1, read / total));
          return chunk;
        }),
      ).toBytes();
      return http.Response.bytes(bytes, streamed.statusCode, headers: streamed.headers, request: streamed.request);
    } on TimeoutException {
      abort.complete();
      rethrow;
    }
  }

  /// Runs [request] once fewer than [maxConcurrent] are running; a finished one hands its slot to the next waiting.
  Future<T> _slot<T>(Future<T> Function() request) async {
    if (_running < maxConcurrent) {
      _running++;
    } else {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    try {
      return await request();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }

  /// The `Retry-After` header in seconds, capped at [_maxWait]; null without one.
  static Duration? _retryAfter(http.Response r) {
    final secs = int.tryParse(r.headers['retry-after'] ?? '');
    if (secs == null) return null;
    final wait = Duration(seconds: secs);
    return wait > _maxWait ? _maxWait : wait;
  }
}
