import 'package:http/http.dart' as http;

/// A Google API answers a quota hit with 429, or with 403 and a rate-limit reason.
bool googleRateLimited(http.Response r) =>
    r.statusCode == 429 || (r.statusCode == 403 && r.body.contains('ateLimitExceeded'));

/// A 403 because the token lacks the API's scope: only a new consent fixes it.
bool googleScopeMissing(http.Response r) =>
    r.statusCode == 403 &&
    (r.body.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') || r.body.contains('insufficientPermissions'));
