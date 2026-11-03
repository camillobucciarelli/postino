import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:routefly/routefly.dart';

import '../../core/domain/accounts_repository.dart';
import '../../core/domain/html_text.dart';
import '../../core/domain/inbox_repository.dart';
import '../../core/domain/mail_sync.dart';
import '../../core/domain/message.dart'
    show Message, draftLabelId, inboxLabelId, sentLabelId;
import '../../core/domain/platform_services.dart' show Clock, Connectivity;
import '../../core/domain/settings_repository.dart';
import '../../main.dart' show routePaths;
import '../../design_system/design_system.dart';
import '../../features/account/presentation/onboarding_gate.dart';
import '../../features/account/presentation/reconnect_banners.dart';
import '../../features/composizione/presentation/composer_view.dart';
import '../../features/posta/presentation/conversation_view.dart';
import '../../features/posta/presentation/message_list.dart';
import '../../features/posta/presentation/offline_banner.dart';
import '../../features/posta/presentation/posta_app_bars.dart';
import '../../features/posta/presentation/posta_drawer.dart';
import '../../features/posta/presentation/posta_shortcuts.dart';
import '../../features/posta/presentation/write_fab.dart';
import '../../i18n/strings.g.dart';

/// Layout of `/posta`: draws the view of the current URI itself (unified, Account, Etichetta, Conversazione),
/// so the outgoing view can fade out with its own params. The child route pages just delegate here.
/// A Conversazione, or the composer of a Bozza, opens beside (from 900) or over its list, which stays mounted: the list it was opened from.
class PostaLayout extends StatefulWidget {
  const PostaLayout({super.key});

  @override
  State<PostaLayout> createState() => _PostaLayoutState();
}

class _PostaLayoutState extends State<PostaLayout> {
  /// The last list shown: a Conversazione stays beside it. Null before any (a deep link).
  String? _list;

  /// What the keyboard shortcuts move: the list in front plugs itself in.
  final _cursor = ListCursor();

  /// The sidebar choice and the list width saved by an earlier run (null: none); the layout waits for it, so the bar does not jump.
  late final Future<(bool?, double?)> _saved = () async {
    final settings = GetIt.I<SettingsRepository>();
    final expanded = await settings.sidebarExpanded();
    return (expanded, _width = await settings.listWidth());
  }();

  /// The current preferred list width: the list is recreated on every Account/Etichetta, so it must outlive it.
  double? _width;

  @override
  Widget build(BuildContext context) {
    // Routefly.of subscribes to route changes; the last configuration is the active route.
    final own = Routefly.of(context).route.uri.path;
    final uri = Routefly.currentUri;
    // Built from the URI, not from Routefly.query, so the outgoing view keeps its own params while it fades out.
    final seg = Routefly.currentOriginalPath == own
        ? const <String>[]
        : uri.pathSegments;
    // (account, conversation) or (account, Message-ID): `pathSegments` decodes the percent-encoding.
    final open = seg.length > 3 && seg[2] == 'conversazione'
        ? (seg[1], seg[3])
        : null;
    final draft = seg.length > 3 && seg[2] == 'bozza' ? (seg[1], seg[3]) : null;
    final detail = open ?? draft;
    final String list;
    if (detail == null) {
      list = _list = uri.path;
    } else {
      final last = _list;
      // Opened from the Posta unificata or from a list of its Account; else (deep link) its inbox.
      list =
          last != null &&
              (last == routePaths.posta.path ||
                  Uri.parse(last).pathSegments[1] == detail.$1)
          ? last
          : routePaths.posta.$accountId.path.changes({'accountId': detail.$1});
    }
    // /posta/<account>[/etichetta/<label>]: the docked drawer reads its selection from the list.
    final ls = Uri.parse(list).pathSegments;
    final accountId = ls.length > 1 ? ls[1] : null;
    final labelId = ls.length > 3 ? ls[3] : null;
    void back() => Routefly.navigate(list);
    // Invia: the composer closes and the Snackbar of Annulla invio shows under this layout's messenger (the
    // app's: PostaLayout outlives the composer in both layouts), so it survives the detail going away.
    void queued(String accountId, String messageId, DateTime until) {
      back();
      PostinoSnackbar.show(
        context,
        message: context.t.composizione.queued,
        actionLabel: context.t.composizione.undo,
        until: until,
        now: GetIt.I<Clock>().now,
        onAction: () => _reopen(accountId, messageId),
      );
    }

    // One shell above the content: only the content is replaced on navigation.
    return OnboardingGate(
      child: FutureBuilder<(bool?, double?)>(
        future: _saved,
        builder: (context, saved) =>
            saved.connectionState != ConnectionState.done
            ? const SizedBox.shrink()
            : PostaShortcuts(
                cursor: _cursor,
                child: PostinoSidebarShell(
                  drawer: postaDrawer(accountId: accountId, labelId: labelId),
                  closeLabel: context.t.sidebar.close,
                  openLabel: context.t.sidebar.open,
                  expanded: saved.data!.$1,
                  onExpandedChanged:
                      GetIt.I<SettingsRepository>().setSidebarExpanded,
                  child: PostinoFadeThrough(
                    transitionKey: list,
                    child: PostinoListDetailLayout(
                      listWidth: _width,
                      onListWidthChanged: (w) {
                        _width = w;
                        GetIt.I<SettingsRepository>().setListWidth(w);
                      },
                      resizeLabel: context.t.listWidth.label,
                      resizeValueLabel: (w) =>
                          context.t.listWidth.value(px: w.round()),
                      list: switch ((accountId, labelId)) {
                        (final a?, draftLabelId) => postaDraftsView(
                          a,
                          selected: detail,
                          cursor: _cursor,
                        ),
                        (final a?, sentLabelId) => postaSentView(
                          a,
                          selected: open,
                          cursor: _cursor,
                        ),
                        (final a?, final l?) => postaLabelView(
                          a,
                          l,
                          selected: open,
                          cursor: _cursor,
                        ),
                        (final a?, null) => postaAccountView(
                          a,
                          selected: open,
                          cursor: _cursor,
                        ),
                        _ => postaUnifiedView(selected: open, cursor: _cursor),
                      },
                      detail: draft != null
                          ? postaComposerView(
                              draft.$1,
                              draft.$2,
                              onClose: back,
                              onQueued: queued,
                            )
                          : open == null
                          ? null
                          : postaConversationView(
                              open.$1,
                              open.$2,
                              onBack: back,
                              cursor: _cursor,
                              onOpenDraft: (id) => _openDraft(open.$1, id),
                            ),
                      detailKey: detail,
                      empty: Builder(
                        builder: (context) => PostinoEmptyState(
                          title: context.t.conversazione.selectTitle,
                          body: context.t.conversazione.selectBody,
                          icon: PostinoIcons.inbox,
                        ),
                      ),
                      onClose: back,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The Posta unificata; [selected] is the Conversazione open beside it.
Widget postaUnifiedView({(String, String)? selected, ListCursor? cursor}) =>
    PostinoAdaptiveLayout(
      appBar: const UnifiedAppBar(),
      drawer: postaDrawer(),
      banners: postaBanners,
      fab: WriteFab(cursor: cursor, onWrite: _openDraft),
      body: MessageList(
        watch: (r) => r.watchUnifiedInbox(),
        showAccount: true,
        selected: selected,
        cursor: cursor,
        onOpen: _openConversation,
      ),
    );

/// An Account's inbox.
Widget postaAccountView(
  String id, {
  (String, String)? selected,
  ListCursor? cursor,
}) => PostinoAdaptiveLayout(
  // A new Account is a new view: its streams start over.
  key: ValueKey(id),
  appBar: AccountAppBar(accountId: id),
  drawer: postaDrawer(accountId: id),
  banners: postaBanners,
  fab: WriteFab(accountId: id, cursor: cursor, onWrite: _openDraft),
  body: MessageList(
    watch: (r) => r.watchMessages(id, inboxLabelId),
    selected: selected,
    cursor: cursor,
    onOpen: _openConversation,
  ),
);

/// The Conversazioni of one Etichetta of an Account.
Widget postaLabelView(
  String accountId,
  String labelId, {
  (String, String)? selected,
  ListCursor? cursor,
}) => PostinoAdaptiveLayout(
  key: ValueKey('$accountId/$labelId'),
  appBar: AccountAppBar(accountId: accountId, labelId: labelId),
  drawer: postaDrawer(accountId: accountId, labelId: labelId),
  banners: postaBanners,
  fab: WriteFab(accountId: accountId, cursor: cursor, onWrite: _openDraft),
  body: MessageList(
    watch: (r) => r.watchMessages(accountId, labelId),
    selected: selected,
    cursor: cursor,
    onOpen: _openConversation,
  ),
);

/// The Bozze of an Account, ours and other clients'; [selected] is the one open beside it.
Widget postaDraftsView(
  String accountId, {
  (String, String)? selected,
  ListCursor? cursor,
}) => Builder(
  key: ValueKey('$accountId/$draftLabelId'),
  builder: (context) => PostinoAdaptiveLayout(
    appBar: AccountAppBar(
      accountId: accountId,
      labelId: draftLabelId,
      labelName: context.t.bozze.title,
    ),
    drawer: postaDrawer(accountId: accountId, labelId: draftLabelId),
    banners: postaBanners,
    fab: WriteFab(accountId: accountId, cursor: cursor, onWrite: _openDraft),
    body: MessageList(
      watch: (r) => _draftEntries(accountId, r),
      selected: selected,
      cursor: cursor,
      emptyTitle: context.t.bozze.emptyTitle,
      emptyBody: context.t.bozze.emptyBody,
      onOpen: _openDraft,
    ),
  ),
);

/// Each Bozza as a row whose Conversazione is its Message-ID: opening it opens the composer, not a thread.
// ponytail: the rows restart on every Accounts change (rare); a combineLatest if the list flickers.
Stream<List<InboxEntry>> _draftEntries(String accountId, InboxRepository r) =>
    GetIt.I<AccountsRepository>().watchAccounts().asyncExpand(
      (accounts) => r
          .watchDrafts(accountId)
          .map(
            (drafts) => [
              for (final a in accounts.where((a) => a.id == accountId))
                for (final m in drafts)
                  InboxEntry(
                    message: Message(
                      id: m.id,
                      messageId: m.messageId,
                      conversationId: m.messageId,
                      labelIds: m.labelIds,
                      isRead: m.isRead,
                      isStarred: m.isStarred,
                      from: m.from,
                      fromName: m.fromName,
                      to: m.to,
                      cc: m.cc,
                      subject: m.subject,
                      snippet: m.snippet,
                      date: m.date,
                    ),
                    account: a,
                    count: 1,
                    unread: false,
                  ),
            ],
          ),
    );

/// The Inviati of an Account: the messages waiting to go, each with its state, over the sent ones.
Widget postaSentView(
  String accountId, {
  (String, String)? selected,
  ListCursor? cursor,
}) => Builder(
  key: ValueKey('$accountId/$sentLabelId'),
  builder: (context) => PostinoAdaptiveLayout(
    appBar: AccountAppBar(
      accountId: accountId,
      labelId: sentLabelId,
      labelName: context.t.inviati.title,
    ),
    drawer: postaDrawer(accountId: accountId, labelId: sentLabelId),
    banners: postaBanners,
    fab: WriteFab(accountId: accountId, cursor: cursor, onWrite: _openDraft),
    body: MessageList(
      watch: (r) => _sentEntries(
        accountId,
        r,
        waiting: context.t.inviati.waiting,
        offline: context.t.inviati.offline,
        failed: context.t.inviati.failed,
      ),
      selected: selected,
      cursor: cursor,
      emptyTitle: context.t.inviati.emptyTitle,
      emptyBody: context.t.inviati.emptyBody,
      // A queued or failed row (its Conversazione is its Message-ID) is cancelled and reopens as a Bozza.
      onOpen: (a, c) =>
          c.startsWith('<') ? _reopen(a, c) : _openConversation(a, c),
    ),
  ),
);

/// The outbox rows first, newest first, then the sent messages. The state sits before the preview:
/// «In attesa d'invio» within the window or online, «In uscita, in attesa di rete» once the window passed offline,
/// «Invio non riuscito» when the Provider refused it for good.
// ponytail: the rows recompute on every outbox change (the failed attempt offline is one), not on the clock: a row
// may read «In attesa d'invio» for the seconds the send takes, then it leaves the outbox.
Stream<List<InboxEntry>> _sentEntries(
  String accountId,
  InboxRepository r, {
  required String waiting,
  required String offline,
  required String failed,
}) => _latest(
  _latest(
    GetIt.I<AccountsRepository>().watchAccounts(),
    _connectivity(),
    (accounts, online) => (accounts, online),
  ),
  _latest(
    r.watchOutbox(accountId),
    r.watchMessages(accountId, sentLabelId),
    (outbox, sent) => (outbox, sent),
  ),
  (context, lists) {
    final (accounts, online) = context;
    final (outbox, sent) = lists;
    final now = GetIt.I<Clock>().now().millisecondsSinceEpoch;
    String state(bool refused, int sendAfter) => refused
        ? failed
        : sendAfter > now || online
        ? waiting
        : offline;
    return [
      for (final a in accounts.where((a) => a.id == accountId))
        for (final OutgoingEntry(message: m, :sendAfter, failed: refused)
            in outbox)
          InboxEntry(
            message: Message(
              id: m.messageId,
              messageId: m.messageId,
              conversationId: m.messageId,
              labelIds: const [sentLabelId],
              isRead: true,
              isStarred: false,
              from: m.from,
              to: m.to,
              cc: m.cc,
              bcc: m.bcc,
              subject: m.subject,
              snippet: '${state(refused, sendAfter)} · ${listSnippet(m.body)}',
              // The end of the window: the time it is listed under until the Provider dates it.
              date: DateTime.fromMillisecondsSinceEpoch(sendAfter, isUtc: true),
            ),
            account: a,
            count: 1,
            unread: false,
            status: state(refused, sendAfter),
          ),
      ...sent,
    ];
  },
);

/// The connection state now, then each change.
Stream<bool> _connectivity() async* {
  final c = GetIt.I<Connectivity>();
  yield c.isOnline;
  yield* c.onChanged;
}

/// Annulla invio of a queued or failed message: when it is still ours, it reopens as a Bozza.
Future<void> _reopen(String accountId, String messageId) async {
  if (await GetIt.I<MailSync>().cancelSend(accountId, messageId)) {
    _openDraft(accountId, messageId);
  }
}

/// [f] of the latest values of [a] and [b], from when both have emitted, on every emission of either.
// ponytail: two streams only; a package combineLatest if a third view needs it.
Stream<R> _latest<A, B, R>(Stream<A> a, Stream<B> b, R Function(A, B) f) {
  late final StreamController<R> c;
  final subs = <StreamSubscription<void>>[];
  (A,)? la;
  (B,)? lb;
  void emit() {
    if ((la, lb) case ((final x,), (final y,))) c.add(f(x, y));
  }

  c = StreamController(
    onListen: () => subs.addAll([
      a.listen((v) {
        la = (v,);
        emit();
      }, onError: c.addError),
      b.listen((v) {
        lb = (v,);
        emit();
      }, onError: c.addError),
    ]),
    onCancel: () => Future.wait(subs.map((s) => s.cancel())),
  );
  return c.stream;
}

/// The composer of a Bozza; its params come from the URI, so a new one is a new view.
Widget postaComposerView(
  String accountId,
  String messageId, {
  required VoidCallback onClose,
  required void Function(String accountId, String messageId, DateTime until)
  onQueued,
}) => ComposerView(
  key: ValueKey('draft-$accountId/$messageId'),
  accountId: accountId,
  messageId: messageId,
  onClose: onClose,
  onQueued: onQueued,
);

void _openDraft(String accountId, String messageId) => Routefly.navigate(
  routePaths.posta.$accountId.bozza.$messageId.changes({
    'accountId': accountId,
    'messageId': Uri.encodeComponent(messageId),
  }),
);

/// An open Conversazione; its params come from the URI, so a new one is a new view.
/// [onOpenDraft]: the composer of the Bozza a Rispondi/Inoltra just saved (#37).
Widget postaConversationView(
  String accountId,
  String conversationId, {
  required VoidCallback onBack,
  required void Function(String messageId) onOpenDraft,
  ListCursor? cursor,
}) => ConversationView(
  key: ValueKey('conversation-$accountId/$conversationId'),
  accountId: accountId,
  conversationId: conversationId,
  onBack: onBack,
  onOpenDraft: onOpenDraft,
  cursor: cursor,
);

void _openConversation(String accountId, String conversationId) =>
    Routefly.navigate(
      routePaths.posta.$accountId.conversazione.$conversationId.changes({
        'accountId': accountId,
        'conversationId': conversationId,
      }),
    );

/// On top of every list: offline, then the Accounts Da ricollegare.
const postaBanners = <Widget>[OfflineBanner(), ReconnectBanners()];

/// The drawer of the Posta views, with the open Account ([accountId]) and Etichetta ([labelId]).
Widget postaDrawer({String? accountId, String? labelId}) => PostaDrawer(
  accountId: accountId,
  labelId: labelId,
  onOpenUnified: () => Routefly.navigate(routePaths.posta.path),
  onOpenAccount: (id) => _openFromPosta(
    routePaths.posta.$accountId.path.changes({'accountId': id}),
  ),
  onOpenLabel: (id) => _openFromPosta(
    routePaths.posta.$accountId.etichetta.$labelId.changes({
      'accountId': accountId!,
      'labelId': id,
    }),
  ),
  onOpenDrafts: (id) => _openFromPosta(
    routePaths.posta.$accountId.etichetta.$labelId.changes({
      'accountId': id,
      'labelId': draftLabelId,
    }),
  ),
  onOpenSent: (id) => _openFromPosta(
    routePaths.posta.$accountId.etichetta.$labelId.changes({
      'accountId': id,
      'labelId': sentLabelId,
    }),
  ),
);

void _openFromPosta(String path) => Routefly.navigate(path);
