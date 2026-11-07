import 'dart:async';
import 'dart:io' show X509Certificate;

import 'package:enough_mail/enough_mail.dart' show ImapClient, Mailbox, ReturnOption;

import '../../domain/action_outcome.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'imap_actions.dart';
import 'imap_cursor.dart';
import 'imap_failure.dart';
import 'imap_folder_create.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_idle.dart';
import 'imap_lookup.dart';
import 'imap_message_parser.dart';
import 'imap_moves.dart';
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

  /// The Message-ID of a message by its Provider id, from the app's cache: how an Azione finds a message whose UID
  /// is gone.
  final MessageIdOf? _messageIdOf,
}) implements MailProvider {
  this
    : _session = ImapSession(_accountId, _address, _keychain, connect: _connect, onBadCertificate: _onBadCertificate);

  final ImapSession _session;
  late final _folders = ImapFolderSync(_session);
  late final _lookup = ImapLookup(_session);
  late final _actions = ImapActions(
    _session,
    _lookup,
    ImapMoves(_session, (c, name) => ensureFolder(c, name, () => _boxes(c))),
    _list,
    _messageIdOf ?? (_) async => null,
  );

  // ponytail: until T4 (#164, bodies on request and Conversazioni), T6 (#166, send and Bozze).
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
        final delta = await _unlessGone(
          () => _folders.window(
            c,
            f,
            since,
            onPage: onPage == null ? null : (page) => onPage(_thread(page, [...all, ...page]), _bodies(page)),
          ),
        );
        if (delta == null) continue;
        all.addAll(delta.messages);
        states[f.path] = delta.state;
      }
      return SyncBatch(
        cursor: ImapCursor(states).encode(),
        labels: _labels(folders),
        messages: _thread(all, all, await _related(c, folders, all)),
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
        final state = was.folders[f.path];
        final delta = await _unlessGone(
          () => state == null ? _folders.window(c, f, since) : _folders.changes(c, f, state, since),
        );
        if (delta == null) {
          // Listed but refused (gone since the LIST, or not readable): as it was, until the next sync.
          if (state != null) states[f.path] = state;
          continue;
        }
        messages.addAll(delta.messages);
        removed.addAll(delta.removed);
        states[f.path] = delta.state;
      }
      // A folder gone (deleted or renamed elsewhere) takes its messages along.
      for (final MapEntry(key: path, value: s) in was.folders.entries) {
        if (states.containsKey(path)) continue;
        removed.addAll([for (final u in s.uids) imapMessageId(path, s.uidValidity, u)]);
      }
      return SyncBatch(
        cursor: ImapCursor(states).encode(),
        labels: _labels(folders),
        messages: _thread(messages, messages, await _related(c, folders, messages)),
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
  Future<Result<Label>> createLabel(String name) =>
      imapGuard(() => _session.run((c) async => _labelOf(await ensureFolder(c, name, () => _boxes(c)))));

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) async => _later('T4');

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) async => _later('T4');

  /// Conditional (ADR 0008): the message is read once, compared and written only if needed.
  @override
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected}) =>
      imapGuard(() => _session.run((c) => _actions.apply(c, messageId, action, expected)));

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
    final folders = imapFolders(await _boxes(c)).where((f) => f.synced).toList();
    return [...folders.where((f) => f.role == FolderRole.inbox), ...folders.where((f) => f.role != FolderRole.inbox)];
  }

  /// Every folder, with `RETURN (SPECIAL-USE)` where announced: a plain LIST may leave the roles out (RFC 6154 §2).
  Future<List<Mailbox>> _boxes(ImapClient c) =>
      c.listMailboxes(recursive: true, returnOptions: _session.specialUse ? [ReturnOption.specialUse()] : null);

  static Label _labelOf(ImapFolder f) => f.label ?? Label(id: f.labelId, name: f.path, kind: LabelKind.cartella);

  static List<Label> _labels(List<ImapFolder> folders) => [for (final f in folders) ?f.label];

  /// [messages] threaded over [known] and the [related] headers looked up on the server.
  List<Message> _thread(List<ImapParsed> messages, List<ImapParsed> known, [List<ThreadInput> related = const []]) =>
      threadMessages(
        [for (final p in messages) _input(p)],
        known: [for (final p in known) _input(p), ...related],
        address: _address,
      );

  Future<List<ThreadInput>> _related(ImapClient c, List<ImapFolder> folders, List<ImapParsed> messages) {
    final inputs = [for (final p in messages) _input(p)];
    return _lookup.related(c, folders, inputs, inputs);
  }

  static ThreadInput _input(ImapParsed p) => (message: p.message, inReplyTo: p.inReplyTo);

  /// [sync] of one folder; null when the server refuses the folder ([NotFoundFailure]).
  static Future<FolderDelta?> _unlessGone(Future<FolderDelta> Function() sync) async {
    try {
      return await sync();
    } on ImapFailed catch (e) {
      if (e.failure is NotFoundFailure) return null;
      rethrow;
    }
  }

  static Map<String, MessageBody> _bodies(List<ImapParsed> messages) => {
    for (final p in messages) p.message.id: ?p.body,
  };
}
