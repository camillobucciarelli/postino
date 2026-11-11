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
import '../mime.dart';
import 'imap_actions.dart';
import 'imap_bodies.dart';
import 'imap_conversations.dart';
import 'imap_cursor.dart';
import 'imap_drafts.dart';
import 'imap_failure.dart';
import 'imap_folder_create.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_idle.dart';
import 'imap_lookup.dart';
import 'imap_message_parser.dart';
import 'imap_moves.dart';
import 'imap_sent.dart';
import 'imap_session.dart';
import 'imap_threads.dart';
import 'password_credentials.dart';
import 'smtp_sender.dart';

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
  SmtpConnector smtpConnect = connectSmtp,

  /// Whether a sent message is APPENDed to Inviati: false for a Provider that files its SMTP submissions itself.
  final bool appendToSent = true,

  /// The Message-ID of a message by its Provider id, from the app's cache: how an Azione finds a message whose UID
  /// is gone.
  final MessageIdOf? _messageIdOf,

  /// The Provider ids of the messages in the app's cache: those outside the sync window (a whole Conversazione
  /// opened) get their flags followed too (#185).
  final Future<Iterable<String>> Function()? _storedIds,
}) implements MailProvider {
  this
    : _session = ImapSession(_accountId, _address, _keychain, connect: _connect, onBadCertificate: _onBadCertificate),
      _smtp = SmtpSender(_accountId, _address, _keychain, connect: smtpConnect, onBadCertificate: _onBadCertificate);

  final ImapSession _session;
  final SmtpSender _smtp;
  late final _folders = ImapFolderSync(_session);
  late final _lookup = ImapLookup(_session);
  late final _actions = ImapActions(
    _session,
    _lookup,
    ImapMoves(_session, (c, name) => ensureFolder(c, name, () => _boxes(c))),
    _list,
    _messageIdOf ?? (_) async => null,
  );

  late final _fetched = ImapBodies(_session);
  late final _conversations = ImapConversations(_session, _address);
  late final _drafts = ImapDrafts(_session);
  late final _sent = ImapSent(_session, _smtp, _drafts, appendToSent: appendToSent);

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
      final stored = <String, List<({String path, int uidValidity, int uid})>>{};
      for (final id in await _storedIds?.call() ?? const <String>[]) {
        if (parseImapMessageId(id) case final p?) (stored[p.path] ??= []).add(p);
      }
      final messages = <ImapParsed>[];
      final removed = <String>[];
      final states = <String, FolderState>{};
      for (final f in folders) {
        final state = was.folders[f.path];
        final delta = await _unlessGone(
          () => state == null
              ? _folders.window(c, f, since)
              : _folders.changes(c, f, state, since, stored: stored[f.path] ?? const []),
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
  Future<Result<MessageBody>> fetchBody(String messageId) => imapGuard(() => _fetched.body(messageId));

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) =>
      imapGuard(() => _session.run((c) async => _conversations.fetch(c, await _list(c), conversationId)));

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
  }) => imapGuard(() => _fetched.attachment(messageId, attachmentId, onProgress: onProgress, cancel: cancel));

  /// [threadId] is not needed: on IMAP the Conversazione comes from `References`, already in [raw].
  @override
  Future<Result<String>> send(
    String messageId,
    String raw, {
    String? threadId,
    bool submitted = false,
    Future<void> Function()? onSubmitted,
  }) => imapGuard(() => _sent.send(messageId, raw, submitted: submitted, onSubmitted: onSubmitted));

  @override
  Future<Result<DraftOutcome>> saveDraft(OutgoingMessage draft, {required bool isNew, String? expected}) =>
      imapGuard(() async {
        final raw = switch (await renderMimeFetching(draft, _clock.now(), fetchAttachment)) {
          Ok(:final value) => value,
          // Never NotFound: the sync engine would drop the Bozza; it stays pending and is retried.
          Err(failure: NotFoundFailure()) => throw const ImapFailed(UnexpectedFailure('forwarded attachment gone')),
          Err(:final failure) => throw ImapFailed(failure),
        };
        return _drafts.save(draft, raw, isNew: isNew, expected: expected);
      });

  @override
  Future<Result<void>> deleteDraft(String messageId) => imapGuard(() => _drafts.delete(messageId));

  DateTime get _since => _clock.now().subtract(syncWindow);

  /// The synced folders (all of them), the inbox first: its page is the first the user sees.
  Future<List<ImapFolder>> _list(ImapClient c) async {
    final folders = imapFolders(await _boxes(c));
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
