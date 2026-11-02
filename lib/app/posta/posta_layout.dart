import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:routefly/routefly.dart';

import '../../core/domain/accounts_repository.dart';
import '../../core/domain/inbox_repository.dart';
import '../../core/domain/message.dart' show Message, inboxLabelId;
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
                          ? postaComposerView(draft.$1, draft.$2, onClose: back)
                          : open == null
                          ? null
                          : postaConversationView(
                              open.$1,
                              open.$2,
                              onBack: back,
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

/// Provider-side id of the Bozze folder: its list is the Account's Bozze, and a row opens the composer.
const draftLabelId = 'DRAFT';

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

/// The composer of a Bozza; its params come from the URI, so a new one is a new view.
Widget postaComposerView(
  String accountId,
  String messageId, {
  required VoidCallback onClose,
}) => ComposerView(
  key: ValueKey('draft-$accountId/$messageId'),
  accountId: accountId,
  messageId: messageId,
  onClose: onClose,
);

void _openDraft(String accountId, String messageId) => Routefly.navigate(
  routePaths.posta.$accountId.bozza.$messageId.changes({
    'accountId': accountId,
    'messageId': Uri.encodeComponent(messageId),
  }),
);

/// An open Conversazione; its params come from the URI, so a new one is a new view.
Widget postaConversationView(
  String accountId,
  String conversationId, {
  required VoidCallback onBack,
}) => ConversationView(
  key: ValueKey('conversation-$accountId/$conversationId'),
  accountId: accountId,
  conversationId: conversationId,
  onBack: onBack,
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
);

void _openFromPosta(String path) => Routefly.navigate(path);
