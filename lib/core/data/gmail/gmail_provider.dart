import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'gmail_tokens.dart';
import 'google_client.dart';

/// Gmail adapter (ADR 0002): one per Account, tokens from the keychain.
// ponytail: only access (token refresh, 401 -> AuthFailure) so far; sync, bodies, send and drafts come with #31.
class GmailProvider implements MailProvider {
  GmailProvider(
    this._accountId,
    this._keychain,
    this._http,
    this._clock, [
    this._client = const GoogleClient.fromEnvironment(),
  ]);

  final String _accountId;
  final SecureStore _keychain;
  final http.Client _http;
  final Clock _clock;
  final GoogleClient _client;

  static final _tokenEndpoint = Uri.parse(
    'https://oauth2.googleapis.com/token',
  );
  static final _api = Uri.parse(
    'https://gmail.googleapis.com/gmail/v1/users/me/',
  );

  static const _todo = Err<Never>(UnexpectedFailure('Gmail: see #31'));

  @override
  Future<Result<void>> refreshAuth() => _guard(() async {
    return switch (await _refresh(await _tokens())) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  });

  @override
  Future<Result<SyncBatch>> initialSync() => _guard(() async {
    // ponytail: the profile call only checks access; the real initial sync is #31.
    return switch (await _get('profile')) {
      Ok() => Err(_todo.failure),
      Err(:final failure) => Err(failure),
    };
  });

  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) => initialSync();

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<Result<String>> fetchBody(String messageId) async => _todo;

  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId,
  ) async => _todo;

  @override
  Future<Result<void>> send(OutgoingMessage message) async => _todo;

  @override
  Future<Result<void>> saveDraft(OutgoingMessage draft) async => _todo;

  @override
  Future<Result<void>> deleteDraft(String messageId) async => _todo;

  Future<GmailTokens?> _tokens() => GmailTokens.read(_keychain, _accountId);

  /// GET on the Gmail API: refreshes an expired token first, and once more on a 401.
  Future<Result<Map<String, dynamic>>> _get(String path) async {
    var tokens = await _tokens();
    if (tokens == null ||
        !_clock.now().isBefore(
          tokens.expiresAt.subtract(const Duration(minutes: 1)),
        )) {
      switch (await _refresh(tokens)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          tokens = value;
      }
    }
    var r = await _send(path, tokens);
    if (r.statusCode == 401) {
      switch (await _refresh(tokens)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          r = await _send(path, value);
      }
    }
    return switch (r.statusCode) {
      200 => Ok(jsonDecode(r.body) as Map<String, dynamic>),
      401 => const Err(AuthFailure()),
      // ponytail: 404/429 -> NotFound/RateLimit with the calls that meet them (#31).
      _ => Err(UnexpectedFailure('Gmail $path: HTTP ${r.statusCode}')),
    };
  }

  Future<http.Response> _send(String path, GmailTokens t) => _http.get(
    _api.resolve(path),
    headers: {'authorization': 'Bearer ${t.access}'},
  );

  /// A revoked or expired refresh token is the Provider's definitive refusal: [AuthFailure].
  Future<Result<GmailTokens>> _refresh(GmailTokens? old) async {
    if (old == null) return const Err(AuthFailure());
    final r = await _http.post(
      _tokenEndpoint,
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': old.refresh,
        ..._client.fields,
      },
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200) {
      final fresh = GmailTokens(
        access: body['access_token'] as String,
        // Google may rotate it.
        refresh: body['refresh_token'] as String? ?? old.refresh,
        expiresAt: _clock.now().add(
          Duration(seconds: body['expires_in'] as int),
        ),
      );
      await fresh.write(_keychain, _accountId);
      return Ok(fresh);
    }
    if (r.statusCode == 401 || body['error'] == 'invalid_grant') {
      return const Err(AuthFailure());
    }
    return Err(UnexpectedFailure('token refresh: HTTP ${r.statusCode}'));
  }

  /// Adapters never throw: no network is [OfflineFailure], anything else [UnexpectedFailure].
  Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } on http.ClientException {
      return const Err(OfflineFailure());
    } catch (e, s) {
      return Err(UnexpectedFailure(e, s));
    }
  }
}
