import 'dart:async';
import 'dart:io' show X509Certificate;

import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException;

import '../../domain/action_outcome.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'imap_cursor.dart';
import 'imap_failure.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_idle.dart';
import 'imap_lookup.dart';
import 'imap_message_parser.dart';
import 'imap_session.dart';
import 'imap_threads.dart';
import 'password_credentials.dart';

/// Headers of the last [syncWindow] are synced (ADR 0003).
const syncWindow = Duration(days: 90);

/// IMAP adapter (ADR 0002) for iCloud and generic IMAP Accounts, one per Account, the password in the keychain.
/// Folders are Etichette ([LabelKind.cartella]); a message's id is `cartella/UIDVALIDITY/UID`.
class ImapProvider(
  final String _accountId,

  /// The Account's address: the user name, and the participant left out when threading.
  final String _address,
  final SecureStore _keychain,
  final Clock _clock, {
  final ImapConnector _connect = connectImap,
  final bool Function(X509Certificate)? _onBadCertificate,
  final ImapIdle _idle = imapIdle,
}) implements MailProvider {
  this
    : _session = ImapSession(_accountId, _address, _keychain, connect: _connect, onBadCertificate: _onBadCertificate);

  final ImapSession _session;
  late final _folders = ImapFolderSync(_session);
  late final _lookup = ImapLookup(_session);

  // ponytail: until T4 (#164, bodies on request and Conversazioni), T5 (#165, Azioni) and T6 (#166, send and Bozze).
  static Err<Never> _later(String ticket) => Err(UnexpectedFailure('IMAP: arrives with $ticket'));

  /// Logs out; the next call logs in again.
  Future<void> close() => _session.close();

  @override
  Future<Result<void>> refreshAuth() => imapGuard(() => _session.run((_) async {}));

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) => imapGuard(
    () => _session.run((c) async {
      final folders = await _list(c);
      final since = _since;
      final all = <ImapParsed>[];
      final states = <String, FolderState>{};
      for (final f in folders) {
        final delta = await _folders.window(
          c,
          f,
          since,
          onPage: onPage == null ? null : (page) => onPage(_thread(page, [...all, ...page]), _bodies(page)),
        );
        all.addAll(delta.messages);
        states[f.path] = delta.state;
      }
      return SyncBatch(
        cursor: ImapCursor(states).encode(),
        labels: _labels(folders),
        messages: _thread(all, all),
        bodies: _bodies(all),
      );
    }),
  );

  /// Logs in first: a refused login wins over an unreadable [cursor], which is [NotFoundFailure].
  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) => imapGuard(
    () => _session.run((c) async {
      final folders = await _list(c);
      final was = ImapCursor.decode(cursor) ?? (throw const ImapFailed(NotFoundFailure()));
      final since = _since;
      final messages = <ImapParsed>[];
      final removed = <String>[];
      final states = <String, FolderState>{};
      for (final f in folders) {
        final delta = switch (was.folders[f.path]) {
          final state? => await _folders.changes(c, f, state, since),
          null => await _folders.window(c, f, since),
        };
        messages.addAll(delta.messages);
        removed.addAll(delta.removed);
        states[f.path] = delta.state;
      }
      // A folder gone (deleted or renamed elsewhere) takes its messages along.
      for (final MapEntry(key: path, value: s) in was.folders.entries) {
        if (states.containsKey(path)) continue;
        removed.addAll([for (final u in s.uids) imapMessageId(path, s.uidValidity, u)]);
      }
      final related = await _lookup.related(c, folders, messages);
      final next = ImapCursor(states).encode();
      return SyncBatch(
        cursor: next,
        labels: _labels(folders),
        messages: threadMessages(
          [for (final p in messages) (message: p.message, inReplyTo: p.inReplyTo)],
          known: [for (final p in messages) (message: p.message, inReplyTo: p.inReplyTo), ...related],
          address: _address,
        ),
        removedMessageIds: removed,
        bodies: _bodies(messages),
      );
    }),
  );

  /// The id of the message with [messageId] in the first synced folder holding it, null if none does: the Azioni
  /// use it when a message's UID is gone (moved elsewhere, T5).
  Future<Result<String?>> findByMessageId(String messageId) =>
      imapGuard(() => _session.run((c) async => _lookup.byMessageId(c, await _list(c), messageId)));

  @override
  Stream<ChangeSignal> get changes async* {
    final credentials = await PasswordCredentials.read(_keychain, _accountId);
    if (credentials == null) {
      yield ChangeSignal.down;
      return;
    }
    final s = credentials.servers.imap;
    yield* _idle(
      host: s.host,
      port: s.port,
      security: s.security,
      user: _address,
      password: () async => (await PasswordCredentials.read(_keychain, _accountId))?.password ?? credentials.password,
      onBadCertificate: _onBadCertificate,
      connect: _connect,
    );
  }

  /// CREATE, idempotent on the name: a folder already there is returned.
  @override
  Future<Result<Label>> createLabel(String name) => imapGuard(
    () => _session.run((c) async {
      Future<ImapFolder?> find() async =>
          imapFolders(await c.listMailboxes(recursive: true))
              .where((f) => f.path == name || f.labelId == name)
              .firstOrNull;
      if (await find() case final f?) return _labelOf(f);
      try {
        await c.createMailbox(name);
      } on ImapException {
        // A CREATE raced by another client, or enough_mail not finding the folder it just created: there it is.
        if (!c.isConnected) rethrow;
      }
      return switch (await find()) {
        final f? => _labelOf(f),
        null => throw ImapFailed(RejectedFailure('the server refused the folder $name')),
      };
    }),
  );

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) async => _later('T4');

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) async => _later('T4');

  @override
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected}) async =>
      _later('T5');

  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async => _later('T4');

  @override
  Future<Result<String>> send(String messageId, String raw, {String? threadId}) async => _later('T6');

  @override
  Future<Result<DraftOutcome>> saveDraft(OutgoingMessage draft, {required bool isNew, String? expected}) async =>
      _later('T6');

  @override
  Future<Result<void>> deleteDraft(String messageId) async => _later('T6');

  DateTime get _since => _clock.now().subtract(syncWindow);

  /// The synced folders, the inbox first: its page is the first the user sees.
  Future<List<ImapFolder>> _list(ImapClient c) async {
    final folders = imapFolders(await c.listMailboxes(recursive: true)).where((f) => f.synced).toList();
    return [...folders.where((f) => f.role == FolderRole.inbox), ...folders.where((f) => f.role != FolderRole.inbox)];
  }

  static Label _labelOf(ImapFolder f) => f.label ?? Label(id: f.labelId, name: f.path, kind: LabelKind.cartella);

  static List<Label> _labels(List<ImapFolder> folders) => [for (final f in folders) ?f.label];

  List<Message> _thread(List<ImapParsed> messages, List<ImapParsed> known) => threadMessages(
    [for (final p in messages) (message: p.message, inReplyTo: p.inReplyTo)],
    known: [for (final p in known) (message: p.message, inReplyTo: p.inReplyTo)],
    address: _address,
  );

  static Map<String, MessageBody> _bodies(List<ImapParsed> messages) => {
    for (final p in messages) p.message.id: ?p.body,
  };
}
