import 'dart:convert' show base64Url;
import 'dart:math' show Random;

import 'package:enough_mail/enough_mail.dart';
import 'package:postino/core/data/imap/imap_folders.dart' show folderLabelId, folderPathOf;
import 'package:postino/core/data/imap/imap_message_parser.dart' show imapMessageId;
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/data/imap/password_credentials.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/mailbox.dart' show parseMailboxes;
import 'package:postino/core/domain/message.dart' as domain show Message, OutgoingMessage;
import 'package:postino/core/domain/message.dart' show LabelKind, draftLabelId, inboxLabelId, sentLabelId, trashLabelId;

import '../core/domain/mail_provider_contract.dart';
import 'fake_platform.dart';
import 'greenmail_server.dart';

/// The "elsewhere" side of the IMAP contract: a user of a GreenMail server, moved by another IMAP client, and the
/// [ImapProvider] logged in as that user. One server for the whole test file ([stopServer] in `tearDownAll`), a new
/// user (a fresh mailbox) for every harness.
class ImapHarness._(final GreenmailServer server, final String login) extends ContractHarness {
  static GreenmailServer? _server;
  static var _users = 0;

  /// The folder of each system Etichetta; any other Etichetta id is the folder's path.
  static const _paths = {inboxLabelId: 'INBOX', sentLabelId: 'Sent', draftLabelId: 'Drafts', trashLabelId: 'Trash'};

  /// The password the adapter logs in with; after [breakAuth] the server has another one.
  // Generated on every run: no password in the source.
  final password = _random();
  final _otherPassword = _random();

  /// The keychain the adapter reads its password from (`password:<id>`, #162).
  final keychain = FakeSecureStore();

  /// Provider ids by `msg` key, where each was last delivered.
  final _ids = <String, String>{};

  String get address => GreenmailServer.addressOf(login);
  String get accountId => 'imap:$address';

  /// A user with the folder `Viaggi` on the file's server (started on first use, or again after [goOffline]).
  static Future<ImapHarness> create() async {
    final server = _server ??= await GreenmailServer.start();
    final h = ImapHarness._(server, 'ada${++_users}');
    await server.createUser(h.login, h.password);
    await PasswordCredentials(
      password: h.password,
      servers: ServerSettings(
        imap: MailServer(host: GreenmailServer.host, port: server.imapsPort, security: ServerSecurity.ssl),
        smtp: MailServer(host: GreenmailServer.host, port: server.smtpsPort, security: ServerSecurity.ssl),
      ),
    ).write(h.keychain, h.accountId);
    await h.withClient((c) => _create(c, 'Viaggi'));
    return h;
  }

  /// Stops the file's server.
  static Future<void> stopServer() async {
    await _server?.stop();
    _server = null;
  }

  @override
  late final ImapProvider provider = ImapProvider(
    accountId,
    address,
    keychain,
    FakeClock(DateTime.now().toUtc()),
    onBadCertificate: (_) => true,
  );

  @override
  Future<void> dispose() => provider.close();

  /// An IMAP client logged in as the user; the certificate is self-signed.
  Future<ImapClient> connect() async {
    final c = ImapClient(onBadCertificate: (_) => true);
    await c.connectToServer(GreenmailServer.host, server.imapsPort);
    await c.login(address, password);
    return c;
  }

  /// Runs [body] with a connected client and closes it (open connections slow the user's deletion down).
  Future<T> withClient<T>(Future<T> Function(ImapClient c) body) async {
    final c = await connect();
    try {
      return await body(c);
    } finally {
      await c.logout();
      await c.disconnect();
    }
  }

  @override
  String idOf(String key) => _ids[key] ?? key;

  @override
  String conversationOf(String key) => '<$key@example.com>';

  @override
  String get viaggiId => folderLabelId('Viaggi');

  @override
  LabelKind get createdKind => LabelKind.cartella;

  @override
  bool get rebuildsExpiredCursor => true;

  /// The folder [m] goes to: the first of its `labelIds` with one, else the inbox.
  static String _pathOf(domain.Message m) =>
      m.labelIds.map((l) => _paths[l] ?? folderPathOf(l)).nonNulls.firstOrNull ?? 'INBOX';

  /// APPEND in the folder `labelIds` says. A message already in the mailbox (same Message-ID) is moved there and
  /// gets the flags of [m] instead: changed elsewhere.
  @override
  Future<void> deliver(domain.Message m) => withClient((c) async {
    final path = _pathOf(m);
    final key = m.messageId.substring(1, m.messageId.indexOf('@'));
    final flags = [if (m.isRead) MessageFlags.seen, if (m.isStarred) MessageFlags.flagged];
    final found = await _find(c, m.messageId);
    if (found == null) {
      await _create(c, path);
      final builder = MessageBuilder.prepareMultipartAlternativeMessage(plainText: 'Ciao', htmlText: '<p>Ciao</p>')
        ..from = [MailAddress(m.fromName, m.from)]
        ..to = m.to.map((a) => MailAddress(null, a)).toList()
        ..cc = [for (final a in m.cc) _address(a)]
        ..subject = m.subject
        ..messageId = m.messageId
        ..date = m.date;
      if (m.references.isNotEmpty) builder.addHeader('References', m.references.join(' '));
      await c.appendMessageText(builder.buildMimeMessage().renderMessage(), targetMailboxPath: path, flags: flags);
    } else {
      if (found.$1 != path) {
        await _create(c, path);
        await c.selectMailboxByPath(found.$1);
        await c.uidMove(MessageSequence.fromId(found.$2, isUid: true), targetMailboxPath: path);
      }
      await c.selectMailboxByPath(path);
      final uid = (await c.uidSearchMessages(searchCriteria: 'HEADER Message-ID "${m.messageId}"')).matchingSequence!;
      await c.uidStore(uid, flags, action: StoreAction.replace);
    }
    final box = await c.selectMailboxByPath(path);
    final uids = (await c.uidSearchMessages(searchCriteria: 'HEADER Message-ID "${m.messageId}"')).matchingSequence;
    _ids[key] = imapMessageId(path, box.uidValidity!, uids!.toList().last);
  });

  /// How many messages with [messageId] [path] holds (a missing folder holds none).
  Future<int> copies(String path, String messageId) => withClient((c) async {
    if (!(await c.listMailboxes(recursive: true)).any((b) => b.path == path)) return 0;
    await c.selectMailboxByPath(path);
    final r = await c.uidSearchMessages(searchCriteria: 'HEADER Message-ID "$messageId"');
    return r.matchingSequence?.length ?? 0;
  });

  /// APPEND of the RFC 5322 text [raw] in [path], as another client.
  Future<void> append(String path, String raw) => withClient((c) async {
    await _create(c, path);
    await c.appendMessageText(raw, targetMailboxPath: path);
  });

  /// `\Deleted` + EXPUNGE of the message with Message-ID `<id@example.com>`, wherever it is.
  @override
  Future<void> removeRemotely(String id) => withClient((c) async {
    for (var found = await _find(c, '<$id@example.com>'); found != null; found = await _find(c, '<$id@example.com>')) {
      final (path, uid) = found;
      await c.selectMailboxByPath(path);
      await c.uidMarkDeleted(MessageSequence.fromId(uid, isUid: true));
      await c.expunge();
    }
  });

  /// The mailbox created again: a new UIDVALIDITY, nothing of the mail before.
  @override
  Future<void> expireCursors() async {
    await server.deleteUser(login);
    await server.createUser(login, password);
  }

  @override
  Future<void> goOffline() async {
    await server.stop();
    if (identical(_server, server)) _server = null;
  }

  /// A new password: the login with the old one is refused.
  @override
  Future<void> breakAuth() async {
    await server.deleteUser(login);
    await server.createUser(login, _otherPassword);
  }

  /// APPEND `\Draft` in Drafts, as another client.
  @override
  Future<void> deliverDraft(domain.OutgoingMessage d) => withClient((c) async {
    await _create(c, 'Drafts');
    await c.appendMessageText(
      renderMime(d, DateTime.utc(2026)),
      targetMailboxPath: 'Drafts',
      flags: [MessageFlags.draft],
    );
  });

  @override
  Future<void> attach(String messageId, String name, List<int> bytes) =>
      throw UnimplementedError('Gli allegati arrivano con T4');

  /// The folder and UID of the message with [messageId], in any folder.
  static Future<(String, int)?> _find(ImapClient c, String messageId) async {
    for (final box in await c.listMailboxes(recursive: true)) {
      if (box.isNotSelectable) continue;
      await c.selectMailbox(box);
      final uids = (await c.uidSearchMessages(searchCriteria: 'HEADER Message-ID "$messageId"')).matchingSequence;
      if (uids != null && uids.isNotEmpty) return (box.path, uids.toList().first);
    }
    return null;
  }

  /// Folders other than the inbox are created on first use (GreenMail has only INBOX).
  static Future<void> _create(ImapClient c, String path) async {
    if (path == 'INBOX' || (await c.listMailboxes(recursive: true)).any((m) => m.path == path)) return;
    try {
      await c.createMailbox(path);
    } on ImapException {
      // enough_mail does not find the folder it just created (LIST with its pattern): it is there all the same.
    }
  }
}

MailAddress _address(String formatted) {
  final m = parseMailboxes(formatted).single;
  return MailAddress(m.name, m.address);
}

String _random() => base64Url.encode([for (var i = 0; i < 12; i++) Random.secure().nextInt(256)]);
