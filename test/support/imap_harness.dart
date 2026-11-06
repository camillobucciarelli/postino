import 'package:enough_mail/enough_mail.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart' as domain show Message, OutgoingMessage;
import 'package:postino/core/domain/message.dart' show inboxLabelId, sentLabelId;

import '../core/domain/mail_provider_contract.dart';
import 'greenmail_server.dart';

/// Il lato "altrove" del contratto IMAP: un utente su un server GreenMail, mosso da un altro client IMAP.
/// I metodi sono asincroni (un'`ImapHarness` riscrive un `void` con un `Future<void>`); i gruppi del contratto
/// li attenderanno quando T3 aggancia l'adapter (`provider`).
class ImapHarness._(final GreenmailServer server) implements ContractHarness {
  static const login = 'ada';

  /// La password con cui l'adapter entra; dopo [breakAuth] il server ne ha un'altra.
  static const password = 'pw-1';
  static const _otherPassword = 'pw-2';
  static const _folders = [('INBOX', inboxLabelId), ('Sent', sentLabelId), ('Drafts', 'DRAFT')];

  /// Avvia il server e crea l'utente.
  static Future<ImapHarness> start() async {
    final server = await GreenmailServer.start();
    try {
      await server.createUser(login, password);
    } catch (_) {
      await server.stop();
      rethrow;
    }
    return ImapHarness._(server);
  }

  Future<void> stop() => server.stop();

  /// Un client IMAP con login come l'utente. Il certificato è autofirmato.
  Future<ImapClient> connect() async {
    final c = ImapClient(onBadCertificate: (_) => true);
    await c.connectToServer(GreenmailServer.host, server.imapsPort);
    await c.login(login, password);
    return c;
  }

  /// Esegue [body] con un client connesso e lo chiude (un server con connessioni aperte rallenta l'eliminazione dell'utente).
  Future<T> withClient<T>(Future<T> Function(ImapClient c) body) async {
    final c = await connect();
    try {
      return await body(c);
    } finally {
      await c.logout();
      await c.disconnect();
    }
  }

  /// Le cartelle che l'utente non ha ancora (GreenMail ha solo INBOX): create alla prima consegna.
  Future<void> _append(ImapClient c, String path, String raw, List<String> flags) async {
    if (path != 'INBOX' && !(await c.listMailboxes()).any((m) => m.path == path)) {
      try {
        await c.createMailbox(path);
      } on ImapException {
        // enough_mail non ritrova la cartella appena creata (LIST con il suo pattern): esiste lo stesso.
      }
    }
    await c.appendMessageText(raw, targetMailboxPath: path, flags: flags);
  }

  @override
  MailProvider get provider => throw UnimplementedError('L\'adapter IMAP arriva con T3');

  /// APPEND nella cartella che dice `labelIds` (posta in arrivo se non ne dice nessuna).
  @override
  Future<void> deliver(domain.Message m) => withClient((c) async {
    final path = _folders.firstWhere((f) => m.labelIds.contains(f.$2), orElse: () => _folders.first).$1;
    final builder = MessageBuilder.prepareMultipartAlternativeMessage(plainText: 'Ciao', htmlText: '<p>Ciao</p>')
      ..from = [MailAddress(m.fromName, m.from)]
      ..to = m.to.map((a) => MailAddress(null, a)).toList()
      ..subject = m.subject
      ..messageId = m.messageId
      ..date = m.date;
    await _append(c, path, builder.buildMimeMessage().renderMessage(), [
      if (m.isRead) MessageFlags.seen,
      if (m.isStarred) MessageFlags.flagged,
    ]);
  });

  /// `\Deleted` + EXPUNGE del messaggio con Message-ID `<id@example.com>`, ovunque sia.
  @override
  Future<void> removeRemotely(String id) => withClient((c) async {
    for (final (path, _) in _folders) {
      try {
        await c.selectMailboxByPath(path);
      } on ImapException {
        continue;
      }
      final found = await c.uidSearchMessages(searchCriteria: 'HEADER Message-ID <$id@example.com>');
      final uids = found.matchingSequence;
      if (uids == null || uids.isEmpty) continue;
      await c.uidMarkDeleted(uids);
      await c.expunge();
    }
  });

  /// Casella ricreata: UIDVALIDITY nuovo, la posta di prima non c'è più.
  @override
  Future<void> expireCursors() async {
    await server.deleteUser(login);
    await server.createUser(login, password);
  }

  @override
  Future<void> goOffline() => server.stop();

  /// Cambio password: il login con quella vecchia è rifiutato.
  @override
  Future<void> breakAuth() async {
    await server.deleteUser(login);
    await server.createUser(login, _otherPassword);
  }

  /// APPEND `\Draft` in Drafts, come un altro client.
  @override
  Future<void> deliverDraft(domain.OutgoingMessage d) =>
      withClient((c) => _append(c, 'Drafts', renderMime(d, DateTime.utc(2026)), [MessageFlags.draft]));

  @override
  Future<void> attach(String messageId, String name, List<int> bytes) =>
      throw UnimplementedError('Gli allegati arrivano con T5');
}
