import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../mime.dart';
import '../oauth/oauth_auth.dart';
import '../oauth/oauth_failed.dart';
import '../oauth/oauth_tokens.dart';
import 'google_client.dart';
import 'google_failure.dart';

/// The Gmail API over HTTP for one Account: tokens from the keychain, refreshed when expired or on a 401,
/// quota hits retried with backoff. Failures are thrown as [OAuthFailed], which [googleGuard] turns into an [Err].
class GmailHttp(
  final String _accountId,
  final SecureStore _keychain,
  final http.Client _http,
  final Clock _clock, {
  required final GoogleClient _client,
  required final Future<void> Function(Duration) _sleep,
  required final Duration _stall,
}) {
  static final _api = Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/');

  /// Retries per request on a quota hit: 1, 2, 4, 8, 16 s (plus jitter), or the server's Retry-After.
  static const _retries = 5;
  static const _maxWait = 32;
  static final _random = Random();

  late final _auth = OAuthAuth(_accountId, _keychain, _http, _clock, client: _client);

  /// Refreshes the access token now.
  Future<void> refreshAuth() async {
    await _auth.refresh(await _auth.tokens());
  }

  /// Tokens with an access token still valid for at least a minute.
  Future<OAuthTokens> validTokens() => _auth.validTokens();

  /// A read: GET [path] with [query].
  /// [onProgress] gets the share of the response read, out of its length or else [expected] bytes;
  /// completing [cancel] aborts it.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object> query = const {},
    int expected = 0,
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) => _request('GET', path, query: query, expected: expected, onProgress: onProgress, cancel: cancel);

  /// A write: [method] on [path], [body] as JSON.
  Future<Map<String, dynamic>> send(String method, String path, {Object? body}) => _request(method, path, body: body);

  /// A call to the Gmail API: refreshes an expired token first and once more on a 401 ([OAuthAuth.authorized]);
  /// retries a quota hit with backoff.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object> query = const {},
    Object? body,
    int expected = 0,
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final url = _api.resolve(path).replace(queryParameters: query.isEmpty ? null : query);
    final payload = body == null ? null : jsonEncode(body);
    // The token of the last try, refreshed or not, for the retries below.
    late String access;
    Future<http.Response> send(String token) =>
        _attempt(method, url, access = token, payload, cancel, expected, onProgress);

    var r = await _auth.authorized(send);
    // Per request, so a quota hit never aborts the page; after the last retry it is a RateLimitFailure.
    for (var n = 0; googleRateLimited(r) && n < _retries; n++) {
      final after = int.tryParse(r.headers['retry-after'] ?? '');
      final wait = after != null
          ? Duration(seconds: min(after, _maxWait))
          : Duration(milliseconds: (min(1 << n, _maxWait) * 1000 * (1 + _random.nextDouble() / 4)).round());
      await _sleep(wait);
      r = await send(access);
    }
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    // batchModify answers with an empty body.
    if (r.statusCode == 204) return const {};
    if (googleRateLimited(r)) {
      // Never the Authorization header or the query: only method, path, status and the start of the body.
      debugPrint(
        '[gmail] rate limited: $method $path ${r.statusCode} '
        '${r.body.length > 300 ? r.body.substring(0, 300) : r.body}',
      );
    }
    throw OAuthFailed(switch (r.statusCode) {
      401 => const AuthFailure(),
      // Token without the Gmail scope: only a new consent fixes it.
      403 when googleScopeMissing(r) => const AuthFailure(),
      // An expired history cursor, or a message that no longer exists.
      404 => const NotFoundFailure(),
      // A message over the 35 MB cap of messages.send.
      413 => const SizeLimitFailure(gmailSendLimitBytes),
      400 when RegExp('too large|size limit', caseSensitive: false).hasMatch(r.body) => const SizeLimitFailure(
        gmailSendLimitBytes,
      ),
      400 => RejectedFailure('Gmail $path: ${_errorMessage(r.body)}'),
      _ when googleRateLimited(r) => RateLimitFailure(retryAfter: _retryAfter(r)),
      _ => UnexpectedFailure('Gmail $path: HTTP ${r.statusCode}'),
    });
  }

  /// One try: sends the request, then reads the answer. A timeout in either step aborts the connection too,
  /// so a replay can never overlap a request still uploading.
  Future<http.Response> _attempt(
    String method,
    Uri url,
    String access,
    String? payload,
    Future<void>? cancel,
    int expected,
    void Function(double done)? onProgress,
  ) async {
    final abort = Completer<void>();
    try {
      final r = await _dispatch(
        method,
        url,
        access,
        payload,
        cancel == null ? abort.future : Future.any([cancel, abort.future]),
      );
      return await _readBody(r, expected, onProgress);
    } on TimeoutException {
      abort.complete();
      rethrow;
    }
  }

  /// Sends the request; the answer must start within [sendTimeout] (a big upload needs time).
  Future<http.StreamedResponse> _dispatch(
    String method,
    Uri url,
    String access,
    String? payload,
    Future<void> abortTrigger,
  ) {
    final request = http.AbortableRequest(method, url, abortTrigger: abortTrigger);
    request.headers['authorization'] = 'Bearer $access';
    if (payload != null) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = payload;
    }
    return _http.send(request).timeout(sendTimeout(request.contentLength, _stall));
  }

  /// Reads the answer, at most [_stall] between two chunks: a long download is fine, a stalled one is not.
  /// [onProgress] gets the share read, out of the response length or else [expected] bytes.
  Future<http.Response> _readBody(http.StreamedResponse r, int expected, void Function(double done)? onProgress) async {
    final total = r.contentLength ?? expected;
    var read = 0;
    final bytes = await http.ByteStream(
      r.stream.timeout(_stall).map((chunk) {
        read += chunk.length;
        if (total > 0) onProgress?.call(min(1, read / total));
        return chunk;
      }),
    ).toBytes();
    return http.Response.bytes(bytes, r.statusCode, headers: r.headers, request: r.request);
  }

  /// The `error.message` of a Google error body, else "HTTP 400".
  static String _errorMessage(String body) {
    try {
      final error = (jsonDecode(body) as Map<String, dynamic>)['error'] as Map<String, dynamic>;
      final m = error['message'];
      if (m is String && m.isNotEmpty) return m;
    } on Object catch (_) {}
    return 'HTTP 400';
  }

  /// The end of a temporary block: "Retry after" plus an ISO timestamp in the body, else the Retry-After header in seconds.
  DateTime? _retryAfter(http.Response r) {
    final at = RegExp(r'Retry after (\S+?Z)').firstMatch(r.body)?.group(1);
    if (at != null) return DateTime.tryParse(at);
    final secs = int.tryParse(r.headers['retry-after'] ?? '');
    return secs == null ? null : _clock.now().add(Duration(seconds: secs));
  }
}

/// Time for the answer to start: [stall] plus 1 s per 50 KB of [bodyBytes] (a 400 kbit/s floor, so 35 MB gets ~12 min).
@visibleForTesting
Duration sendTimeout(int bodyBytes, [Duration stall = const Duration(seconds: 30)]) =>
    stall + Duration(milliseconds: bodyBytes ~/ 50);
