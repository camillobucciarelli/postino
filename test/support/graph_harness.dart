// Microsoft Graph as seen over HTTP: the token endpoint and a simulated Outlook.com mailbox (folders, messages,
// delta queries), shaped like the responses of test/fixtures/graph.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/microsoft/microsoft_provider.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/mailbox.dart';
import 'package:postino/core/domain/message.dart';

import '../core/domain/mail_provider_contract.dart';
import 'fake_platform.dart';
import 'graph_recorded.dart';

typedef _Folder = ({String name, String? parent, String? wellKnown});

class GraphHarness({String access = 'EwB.initial'}) extends ContractHarness {
  this : keychain = graphKeychain(access: access);

  final FakeSecureStore keychain;
  final requests = <http.Request>[];

  final _accepted = {'EwB.initial', 'EwB.refreshed'};
  var _authBroken = false;
  var _offline = false;

  /// The folders by Graph id; the display names are the Italian ones of an Outlook.com mailbox.
  final _folders = <String, _Folder>{
    'f-inbox': (name: 'Posta in arrivo', parent: null, wellKnown: 'inbox'),
    'f-sent': (name: 'Posta inviata', parent: null, wellKnown: 'sentitems'),
    'f-drafts': (name: 'Bozze', parent: null, wellKnown: 'drafts'),
    'f-deleted': (name: 'Posta eliminata', parent: null, wellKnown: 'deleteditems'),
    'f-junk': (name: 'Posta indesiderata', parent: null, wellKnown: 'junkemail'),
    'f-outbox': (name: 'Posta in uscita', parent: null, wellKnown: 'outbox'),
    'f-viaggi': (name: 'Viaggi', parent: null, wellKnown: null),
  };

  /// The folder of each system Etichetta; any other Etichetta id is a folder id.
  static const _system = {
    inboxLabelId: 'f-inbox',
    sentLabelId: 'f-sent',
    draftLabelId: 'f-drafts',
    trashLabelId: 'f-deleted',
    spamLabelId: 'f-junk',
  };

  /// Each message and the folder it is in.
  final _mailbox = <String, (Message, String)>{};

  /// Every change, in order: (sequence number, folder id, message id); a folder change has no message id.
  final _log = <(int, String, String?)>[];
  var _seq = 0;

  /// Bumped by [expireCursors]: every link of an older epoch is a 410.
  var _epoch = 0;

  /// The adapter's clock: the messages of the contract (January 2026) are inside its 90 days.
  static final now = DateTime.utc(2026, 3);

  /// Tiny pages exercise `@odata.nextLink`.
  static const _page = 2;

  @override
  late final MailProvider provider = MicrosoftProvider(
    graphAccount,
    keychain,
    MockClient(_handle),
    FakeClock(now),
    client: graphTestClient,
    sleep: (_) async {},
  );

  @override
  String get viaggiId => 'f-viaggi';

  @override
  LabelKind get createdKind => LabelKind.cartella;

  @override
  bool get labelsAreFolders => true;

  /// The folder [m] goes to: the first of its `labelIds` with one, else the inbox.
  String _folderOf(Message m) =>
      m.labelIds.map((l) => _system[l] ?? (_folders.containsKey(l) ? l : null)).nonNulls.firstOrNull ?? 'f-inbox';

  /// Delivered again (same id), the message changes: its flags, or its folder, keeping its immutable id.
  @override
  void deliver(Message m) {
    final folder = _folderOf(m);
    final was = _mailbox[m.id]?.$2;
    _mailbox[m.id] = (m, folder);
    _seq++;
    if (was != null && was != folder) _log.add((_seq, was, m.id));
    _log.add((_seq, folder, m.id));
  }

  @override
  void removeRemotely(String id) {
    if (_mailbox.remove(id) case (_, final folder)) _log.add((++_seq, folder, id));
  }

  /// A folder created by another client.
  void createFolderElsewhere(String id, String name, {String? parent}) {
    _folders[id] = (name: name, parent: parent, wellKnown: null);
    _log.add((++_seq, id, null));
  }

  /// A folder deleted by another client: Outlook moves it, with its messages, into Posta eliminata.
  void deleteFolderElsewhere(String id) {
    final f = _folders[id]!;
    _folders[id] = (name: f.name, parent: 'f-deleted', wellKnown: null);
    _log.add((++_seq, id, null));
  }

  @override
  void expireCursors() => _epoch++;

  @override
  void goOffline() => _offline = true;

  @override
  void breakAuth() {
    _authBroken = true;
    _accepted.clear();
  }

  @override
  void deliverDraft(OutgoingMessage d) => throw UnimplementedError('Bozze on Microsoft: T5');

  @override
  void attach(String messageId, String name, List<int> bytes) => throw UnimplementedError('attachments: T3');

  /// Sees every request before it is answered: a change "elsewhere" can land in the middle of a sync.
  void Function(http.Request r)? onRequest;

  Future<http.Response> _handle(http.Request r) async {
    requests.add(r);
    onRequest?.call(r);
    if (_offline) throw http.ClientException('Failed host lookup');
    if (r.url.host == tokenHost) return graphFixture(_authBroken ? 'token_invalid_grant' : 'token_refresh');
    if (!_accepted.contains(r.headers['authorization']?.substring('Bearer '.length))) {
      return graphFixture('unauthorized');
    }
    final q = r.url.queryParameters;
    return switch (graphPath(r).split('/')) {
      ['mailFolders'] when r.method == 'POST' => _create((jsonDecode(r.body) as Map<String, dynamic>)['displayName']),
      ['mailFolders'] => _children(null),
      ['mailFolders', 'delta'] => _folderDelta(q),
      ['mailFolders', final id, 'childFolders'] => _children(id),
      ['mailFolders', final id, 'messages', 'delta'] => _messageDelta(id, q),
      ['messages', final id] => switch (_mailbox[id]) {
        (final m, final folder) => graphJson(_item(m, folder, r.url.queryParameters[r'$select'] ?? '')),
        null => graphFixture('not_found'),
      },
      ['mailFolders', final name] => switch ([
        for (final MapEntry(:key, :value) in _folders.entries)
          if (value.wellKnown == name) key,
      ]) {
        [final id] => graphJson({'id': id}),
        _ => graphFixture('not_found'),
      },
      final path => throw StateError('unexpected Graph request $path'),
    };
  }

  Map<String, Object?> _folderJson(String id) {
    final f = _folders[id]!;
    return {
      'id': id,
      'displayName': f.name,
      'parentFolderId': f.parent ?? 'f-root',
      'childFolderCount': _folders.values.where((c) => c.parent == id).length,
    };
  }

  http.Response _children(String? parent) => graphJson({
    'value': [
      for (final MapEntry(:key, :value) in _folders.entries)
        if (value.parent == parent) _folderJson(key),
    ],
  });

  /// `ErrorFolderExists` for a name already at the top, ignoring case.
  http.Response _create(Object? name) {
    final taken = _folders.values.any((f) => f.parent == null && f.name.toLowerCase() == '$name'.toLowerCase());
    if (taken) return graphFixture('folder_exists');
    final id = 'f-${'$name'.toLowerCase()}';
    createFolderElsewhere(id, '$name');
    return graphJson(_folderJson(id), 201);
  }

  /// A delta link: `<epoch>.<sequence>` of the last change it saw.
  String _link(String path, String token, [Map<String, String> keep = const {}]) =>
      Uri.https('graph.microsoft.com', '$graphApi$path', {...keep, r'$deltatoken': token}).toString();

  /// The `<epoch>.<sequence>[.<offset>]` of a delta or skip token; null for a first round.
  List<int>? _token(String? token) => token?.split('.').map(int.parse).toList();

  http.Response _folderDelta(Map<String, String> q) {
    final token = _token(q[r'$deltatoken']);
    if (token != null && token[0] != _epoch) return graphFixture('delta_expired');
    final changed = token == null
        ? _folders.keys
        : {
            for (final (seq, folder, message) in _log)
              if (seq > token[1] && message == null) folder,
          };
    return graphJson({
      'value': [for (final id in changed) _folderJson(id)],
      '@odata.deltaLink': _link('mailFolders/delta', '$_epoch.$_seq'),
    });
  }

  /// A first round lists the folder, newest first; a later one gives each message changed in it since the token,
  /// in its last state, or `@removed` when it is no longer there.
  http.Response _messageDelta(String folder, Map<String, String> q) {
    final skip = _token(q[r'$skiptoken']);
    final token = skip ?? _token(q[r'$deltatoken']);
    if (token != null && token[0] != _epoch) return graphFixture('delta_expired');
    // The sequence the round starts after; -1 for a first round.
    final from = token?[1] ?? -1;
    final offset = skip?[2] ?? 0;
    // The window of the first round, `receivedDateTime ge <date>`, as Graph applies it.
    final window = q[r'$filter'];
    final since = window == null ? null : DateTime.parse(window.split(' ').last);
    final ids = from < 0
        ? ([
            for (final MapEntry(:key, :value) in _mailbox.entries)
              if (value.$2 == folder && !(since != null && value.$1.date.isBefore(since))) (key, value.$1.date),
          ]..sort((a, b) => b.$2.compareTo(a.$2))).map((e) => e.$1).toList()
        : <String>{
            for (final (seq, f, message) in _log)
              if (seq > from && f == folder && message != null) message,
          }.toList();
    final path = 'mailFolders/$folder/messages/delta';
    final keep = {r'$select': q[r'$select'] ?? '', r'$filter': ?window};
    final more = offset + _page < ids.length;
    return graphJson({
      'value': [
        for (final id in ids.skip(offset).take(_page))
          if (_mailbox[id] case (final m, final f) when f == folder)
            _item(m, folder, keep[r'$select']!)
          else
            {
              'id': id,
              '@removed': {'reason': 'deleted'},
            },
      ],
      if (more)
        '@odata.nextLink': Uri.https('graph.microsoft.com', '$graphApi$path', {
          ...keep,
          r'$skiptoken': '$_epoch.$from.${offset + _page}',
        }).toString()
      else
        '@odata.deltaLink': _link(path, '$_epoch.$_seq', keep),
    });
  }

  static Map<String, Object?> _item(Message m, String folder, String select) => {
    'id': m.id,
    'internetMessageId': m.messageId,
    'conversationId': m.conversationId,
    'parentFolderId': folder,
    'isRead': m.isRead,
    'flag': {'flagStatus': m.isStarred ? 'flagged' : 'notFlagged'},
    'from': _recipient(formatMailbox((name: m.fromName, address: m.from))),
    'toRecipients': m.to.map(_recipient).toList(),
    'ccRecipients': m.cc.map(_recipient).toList(),
    'bccRecipients': m.bcc.map(_recipient).toList(),
    'replyTo': [],
    'subject': m.subject,
    'bodyPreview': m.snippet,
    'receivedDateTime': m.date.toIso8601String(),
    'hasAttachments': false,
    if (select.split(',').contains('body')) 'body': {'contentType': 'html', 'content': '<p>Ciao</p>'},
  };

  /// Outlook gives the address as the name when there is none.
  static Map<String, Object?> _recipient(String formatted) {
    final m = parseMailbox(formatted);
    return {
      'emailAddress': {'name': m.name ?? m.address, 'address': m.address},
    };
  }
}
