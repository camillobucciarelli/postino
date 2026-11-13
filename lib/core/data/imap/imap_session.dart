import 'dart:async';
import 'dart:io' show X509Certificate;

import 'package:enough_mail/enough_mail.dart';

import '../../domain/mail_servers.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'imap_failure.dart';
import 'password_credentials.dart';

/// How a client reaches [server] before the login; tests swap it for a plain socket to a recorded server.
typedef ImapConnector = Future<void> Function(ImapClient client, MailServer server);

/// TLS from the first byte, or a plain connection upgraded with STARTTLS: never the password in clear.
Future<void> connectImap(ImapClient client, MailServer server) async {
  await client.connectToServer(server.host, server.port, isSecure: server.security == ServerSecurity.ssl);
  if (server.security == ServerSecurity.starttls) await client.startTls();
}

/// One logged-in IMAP connection per Account, opened on first use with the password in the keychain
/// (`password:<id>`, #162) and opened again when it drops. Commands run one at a time: the selected folder is
/// connection state.
class ImapSession(
  final String _accountId,

  /// The user name: the Account's address.
  final String _user,
  final SecureStore _keychain, {
  final ImapConnector _connect = connectImap,
  final bool Function(X509Certificate)? _onBadCertificate,
}) {
  /// A command that hangs past this is an unreachable server.
  // ponytail: one timeout for every command; a longer one for big body pages if slow links time out.
  static const timeout = Duration(minutes: 2);

  ImapClient? _client;
  Future<void> _tail = Future.value();

  /// The client logging in now, and how many times [close] ran: a close during a login drops that login (#191).
  ImapClient? _opening;
  var _closes = 0;

  /// CONDSTORE (RFC 7162) is announced after the login; [qresync] too, and it is then enabled.
  /// iCloud announces neither before the login (`ricerca-server-per-provider.md` §3): read only after it.
  bool condstore = false;
  bool qresync = false;

  /// SPECIAL-USE (RFC 6154): the folder roles come only when LIST asks for them.
  bool specialUse = false;

  /// MOVE (RFC 6851) and UIDPLUS (`UID EXPUNGE`, RFC 4315): without MOVE a move is COPY, `\Deleted` and EXPUNGE.
  bool move = false;
  bool uidPlus = false;

  /// PARTIAL (RFC 9394): `SEARCH RETURN (PARTIAL ...)` answers a window of the results, not all of them (#208).
  bool partial = false;

  /// Runs [body] on the connection, after the commands queued before it. A connection that dropped while unused
  /// is opened again once; any error is thrown as [ImapFailed]. A new connection that is not logged in and read within
  /// [setup] is dropped, an [OfflineFailure] (the sync waits as long as the commands do; a search has a deadline).
  Future<T> run<T>(Future<T> Function(ImapClient c) body, {Duration? setup}) {
    final run = _tail.then((_) => _run(body, setup));
    _tail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<T> _run<T>(Future<T> Function(ImapClient c) body, Duration? setup) async {
    if (_client case final c? when c.isConnected && c.isLoggedIn) {
      try {
        return await body(c);
      } on ImapFailed {
        rethrow;
      } on Object catch (e) {
        if (c.isConnected) throw ImapFailed(imapFailure(e, atLogin: false, connected: true));
        _client = null;
      }
    }
    final c = await _open(setup);
    try {
      return await body(c);
    } on ImapFailed {
      rethrow;
    } on Object catch (e) {
      throw ImapFailed(imapFailure(e, atLogin: false, connected: c.isConnected));
    }
  }

  Future<ImapClient> _open(Duration? setup) async {
    final closes = _closes;
    final credentials = await PasswordCredentials.read(_keychain, _accountId);
    if (credentials == null) throw const ImapFailed(AuthFailure());
    final c = ImapClient(
      defaultResponseTimeout: timeout,
      defaultWriteTimeout: timeout,
      onBadCertificate: _onBadCertificate,
    );
    _opening = c;
    var atLogin = false;
    Future<void> setUp() async {
      await _connect(c, credentials.servers.imap);
      atLogin = true;
      await c.login(_user, credentials.password);
      atLogin = false;
      final capabilities = {for (final x in await c.capability()) x.name.toUpperCase()};
      qresync = capabilities.contains('QRESYNC');
      condstore = qresync || capabilities.contains('CONDSTORE');
      specialUse = capabilities.contains('SPECIAL-USE');
      move = capabilities.contains('MOVE');
      uidPlus = capabilities.contains('UIDPLUS');
      partial = capabilities.contains('PARTIAL');
      if (qresync) await c.enable(['QRESYNC']);
    }

    try {
      await (setup == null ? setUp() : setUp().timeout(setup));
      // Closed meanwhile (the Account removed, #191): this login is not kept.
      if (closes != _closes) throw const ImapFailed(OfflineFailure());
      return _client = c;
    } on Object catch (e) {
      // A close cuts the connection: what the login then throws is no refusal of the credentials.
      final failure = closes != _closes
          ? const OfflineFailure()
          : imapFailure(e, atLogin: atLogin, connected: c.isConnected);
      unawaited(_quietly(c.disconnect));
      throw ImapFailed(failure);
    } finally {
      if (identical(_opening, c)) _opening = null;
    }
  }

  /// Logs out, best effort, and drops a login in flight; the next [run] opens a new connection.
  Future<void> close() async {
    _closes++;
    if (_opening case final opening?) unawaited(_quietly(opening.disconnect));
    final c = _client;
    _client = null;
    if (c == null) return;
    await _quietly(c.logout);
    await _quietly(c.disconnect);
  }
}

/// Selects [path]: a folder the server refuses (gone, or not readable) is [NotFoundFailure]; a timeout or a lost
/// connection goes on to [imapFailure] (offline).
Future<Mailbox> selectFolder(ImapClient c, String path, {bool condstore = false}) async {
  try {
    return await c.selectMailboxByPath(path, enableCondStore: condstore);
  } on ImapException catch (e) {
    if (!c.isConnected || e.message == 'timeout') rethrow;
    throw const ImapFailed(NotFoundFailure());
  }
}

/// Released within a few seconds: a LOGOUT to a server that died waits for an answer that never comes.
Future<void> _quietly(Future<Object?> Function() close) async {
  try {
    await close().timeout(const Duration(seconds: 5));
  } on Object {
    // Already closed or never opened: nothing to release.
  }
}
