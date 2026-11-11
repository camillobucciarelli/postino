import 'package:http/http.dart' as http;

import '../../domain/action_outcome.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';
import '../oauth/oauth_guard.dart';
import 'graph_cursor.dart';
import 'graph_delta.dart';
import 'graph_folders.dart';
import 'graph_http.dart';
import 'graph_message_parser.dart';
import 'microsoft_client.dart';

/// Microsoft Graph adapter (ADR 0002) for a personal Outlook.com Account: folders are Etichette
/// ([LabelKind.cartella]), a message's id is Graph's immutable id, its Conversazione Graph's `conversationId`.
/// No change signal in v1 (no `IMAP.AccessAsUser.All`, ADR 0008): the poll every 60 s brings the changes.
class MicrosoftProvider(
  String accountId,
  SecureStore keychain,
  http.Client httpClient,
  final Clock _clock, {
  MicrosoftClient client = const MicrosoftClient.fromEnvironment(),
  Future<void> Function(Duration) sleep = Future<void>.delayed,
}) implements MailProvider {
  this : _graph = GraphHttp(accountId, keychain, httpClient, _clock, client: client, sleep: sleep);

  // ponytail: bodies on request, attachments and Conversazioni (T3), Azioni (T4), sending and Bozze (T5).
  static const _unsupported = Err<Never>(UnexpectedFailure('Microsoft: not available yet'));

  final GraphHttp _graph;
  late final _folders = GraphFolders(_graph);
  late final _delta = GraphDelta(_graph);

  @override
  Future<Result<void>> refreshAuth() => oauthGuard(() async {
    await _graph.refreshAuth();
    return const Ok(null);
  });

  @override
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage}) => oauthGuard(() async {
    // The cursor comes first: a folder that changes while listing shows up in the next incremental sync.
    final (_, folderLink) = await _folders.delta(null);
    final folders = await _folders.list();
    final since = _clock.now().subtract(syncWindow);
    final messages = <String, Message>{};
    final bodies = <String, MessageBody>{};
    final links = <String, FolderLink>{};
    for (final f in folders) {
      final d = await _delta.start(f.id, f.labelId, since, onPage: onPage);
      messages.addAll(d.messages);
      bodies.addAll(d.bodies);
      links[f.id] = (label: f.labelId, link: d.link);
    }
    return Ok(
      SyncBatch(
        cursor: GraphCursor(folderLink, links).encode(),
        labels: [for (final f in folders) ?f.label],
        messages: messages.values.toList(),
        bodies: bodies,
      ),
    );
  });

  /// A refused login wins over an unreadable [cursor], which is [NotFoundFailure].
  @override
  Future<Result<SyncBatch>> incrementalSync(String cursor) => oauthGuard(() async {
    final was = GraphCursor.decode(cursor);
    if (was == null) {
      await _graph.refreshAuth();
      throw const OAuthFailed(NotFoundFailure());
    }
    final (changed, folderLink) = await _folders.delta(was.folders);
    // The folders are listed again only when one came, changed or went; else the Etichette stay as stored.
    final folders = changed ? await _folders.list() : null;
    final synced = folders == null
        ? {for (final MapEntry(:key, :value) in was.messages.entries) key: value.label}
        : {for (final f in folders) f.id: f.labelId};
    // ponytail: a folder gone (deleted, or moved into Cestino) takes its messages along through a new initial sync,
    // whose snapshot drops them; keep the ids per folder if folders get deleted often.
    if (was.messages.keys.any((id) => !synced.containsKey(id))) throw const OAuthFailed(NotFoundFailure());
    final since = _clock.now().subtract(syncWindow);
    final messages = <String, Message>{};
    final bodies = <String, MessageBody>{};
    final removed = <String>{};
    final links = <String, FolderLink>{};
    for (final MapEntry(key: id, value: label) in synced.entries) {
      final link = was.messages[id]?.link;
      // A new folder starts with its first round.
      final d = link == null ? await _delta.start(id, label, since) : await _delta.follow(link, label);
      messages.addAll(d.messages);
      bodies.addAll(d.bodies);
      removed.addAll(d.removed);
      links[id] = (label: label, link: d.link);
    }
    // A message moved between two folders is removed from one and new in the other, with the same id: it stays.
    removed.removeAll(messages.keys);
    // A removal alone may be a move: between two folder rounds (of this sync or the last), or of a message older
    // than the window, which the destination's filtered delta never reports. A message still in a synced folder
    // stays, with that folder's Etichetta.
    // ponytail: one GET per removed message; fine for the few deletions of a poll.
    for (final id in removed.toList()) {
      final now = await _delta.current(id);
      if (synced[now?['parentFolderId']] case final label?) {
        removed.remove(id);
        messages[id] = parseGraphMessage(now!, labelId: label);
      }
    }
    return Ok(
      SyncBatch(
        cursor: GraphCursor(folderLink, links).encode(),
        labels: folders == null ? null : [for (final f in folders) ?f.label],
        messages: messages.values.toList(),
        removedMessageIds: removed.toList(),
        bodies: bodies,
      ),
    );
  });

  @override
  Stream<ChangeSignal> get changes => Stream.value(ChangeSignal.down);

  @override
  Future<Result<Label>> createLabel(String name) => oauthGuard(() async => Ok(await _folders.create(name)));

  @override
  Future<Result<MessageBody>> fetchBody(String messageId) async => _unsupported;

  @override
  Future<Result<List<Message>>> fetchConversation(String conversationId) async => _unsupported;

  @override
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected}) async =>
      _unsupported;

  @override
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async => _unsupported;

  @override
  Future<Result<String>> send(
    String messageId,
    String raw, {
    String? threadId,
    bool submitted = false,
    Future<void> Function()? onSubmitted,
  }) async => _unsupported;

  @override
  Future<Result<DraftOutcome>> saveDraft(OutgoingMessage draft, {required bool isNew, String? expected}) async =>
      _unsupported;

  @override
  Future<Result<void>> deleteDraft(String messageId) async => _unsupported;
}
