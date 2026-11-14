import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:routefly/routefly.dart';

import '../../core/domain/mail_sync.dart';
import '../../core/domain/message.dart' show draftLabelId, inboxLabelId, sentLabelId;
import '../../core/presentation/app_update_banner.dart';
import '../../core/presentation/model_download_banner.dart';
import '../../design_system/design_system.dart';
import '../../features/account/presentation/reconnect_banners.dart';
import '../../features/composizione/presentation/composer_view.dart';
import '../../features/posta/presentation/conflicts_banner.dart';
import '../../features/posta/presentation/conversation_view.dart';
import '../../features/posta/presentation/message_list.dart';
import '../../features/posta/presentation/offline_banner.dart';
import '../../features/posta/presentation/outbox_entries.dart';
import '../../features/posta/presentation/posta_app_bars.dart';
import '../../features/posta/presentation/posta_drawer.dart';
import '../../features/posta/presentation/posta_shortcuts.dart';
import '../../features/posta/presentation/sync_status_row.dart';
import '../../features/posta/presentation/write_fab.dart';
import '../../i18n/strings.g.dart';
import '../../main.dart' show routePaths;
import '../report_problem.dart';
import 'posta_routes.dart';

/// The Posta unificata; [selected] is the Conversazione open beside it.
Widget postaUnifiedView({(String, String)? selected, ListCursor? cursor}) => PostinoAdaptiveLayout(
  appBar: const UnifiedAppBar(onSearch: openSearch),
  drawer: postaDrawer(),
  banners: [const SyncStatusRow(), ...postaBanners, conflictsBanner()],
  fab: WriteFab(cursor: cursor, onWrite: openDraft),
  body: MessageList(
    watch: (r) => r.watchUnifiedInbox(),
    showAccount: true,
    selected: selected,
    cursor: cursor,
    onOpen: openConversation,
  ),
);

/// An Account's inbox.
Widget postaAccountView(String id, {(String, String)? selected, ListCursor? cursor}) => PostinoAdaptiveLayout(
  // A new Account is a new view: its streams start over.
  key: ValueKey(id),
  appBar: AccountAppBar(
    accountId: id,
    onSearch: () => openSearch(accountId: id),
  ),
  drawer: postaDrawer(accountId: id),
  banners: [
    SyncStatusRow(accountId: id),
    ...postaBanners,
    conflictsBanner(accountId: id),
  ],
  fab: WriteFab(accountId: id, cursor: cursor, onWrite: openDraft),
  body: MessageList(
    watch: (r) => r.watchMessages(id, inboxLabelId),
    selected: selected,
    cursor: cursor,
    onOpen: openConversation,
  ),
);

/// The Conversazioni of one Etichetta of an Account.
Widget postaLabelView(String accountId, String labelId, {(String, String)? selected, ListCursor? cursor}) =>
    PostinoAdaptiveLayout(
      key: ValueKey('$accountId/$labelId'),
      appBar: AccountAppBar(
        accountId: accountId,
        labelId: labelId,
        onSearch: () => openSearch(accountId: accountId, labelId: labelId),
      ),
      drawer: postaDrawer(accountId: accountId, labelId: labelId),
      banners: [
        SyncStatusRow(accountId: accountId),
        ...postaBanners,
      ],
      fab: WriteFab(accountId: accountId, cursor: cursor, onWrite: openDraft),
      body: MessageList(
        watch: (r) => r.watchMessages(accountId, labelId),
        selected: selected,
        cursor: cursor,
        onOpen: openConversation,
      ),
    );

/// The Bozze of an Account, ours and other clients'; [selected] is the one open beside it.
Widget postaDraftsView(String accountId, {(String, String)? selected, ListCursor? cursor}) => Builder(
  key: ValueKey('$accountId/$draftLabelId'),
  builder: (context) => PostinoAdaptiveLayout(
    appBar: AccountAppBar(
      accountId: accountId,
      labelId: draftLabelId,
      labelName: context.t.bozze.title,
      onSearch: () => openSearch(accountId: accountId),
    ),
    drawer: postaDrawer(accountId: accountId, labelId: draftLabelId),
    banners: [
      SyncStatusRow(accountId: accountId),
      ...postaBanners,
    ],
    fab: WriteFab(accountId: accountId, cursor: cursor, onWrite: openDraft),
    body: MessageList(
      watch: (r) => draftEntries(accountId, r),
      selected: selected,
      cursor: cursor,
      emptyTitle: context.t.bozze.emptyTitle,
      emptyBody: context.t.bozze.emptyBody,
      onOpen: openDraft,
    ),
  ),
);

/// The Inviati of an Account: the messages waiting to go, each with its state, over the sent ones.
Widget postaSentView(String accountId, {(String, String)? selected, ListCursor? cursor}) => Builder(
  key: ValueKey('$accountId/$sentLabelId'),
  builder: (context) => PostinoAdaptiveLayout(
    appBar: AccountAppBar(
      accountId: accountId,
      labelId: sentLabelId,
      labelName: context.t.inviati.title,
      onSearch: () => openSearch(accountId: accountId),
    ),
    drawer: postaDrawer(accountId: accountId, labelId: sentLabelId),
    banners: [
      SyncStatusRow(accountId: accountId),
      ...postaBanners,
    ],
    fab: WriteFab(accountId: accountId, cursor: cursor, onWrite: openDraft),
    body: MessageList(
      watch: (r) => sentEntries(
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
      onOpen: (a, c) => c.startsWith('<') ? reopenAsDraft(a, c) : openConversation(a, c),
    ),
  ),
);

/// Annulla invio of a queued or failed message: when it is still ours, it reopens as a Bozza.
Future<void> reopenAsDraft(String accountId, String messageId) async {
  final id = await GetIt.I<MailSync>().cancelSend(accountId, messageId);
  if (id != null) openDraft(accountId, id);
}

/// The composer of a Bozza; its params come from the URI, so a new one is a new view.
Widget postaComposerView(
  String accountId,
  String messageId, {
  required VoidCallback onClose,
  required void Function(String accountId, String messageId, DateTime until) onQueued,
}) => ComposerView(
  key: ValueKey('draft-$accountId/$messageId'),
  accountId: accountId,
  messageId: messageId,
  onClose: onClose,
  onQueued: onQueued,
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

/// On top of every list, under its sync status: offline, then the Accounts Da ricollegare, the model download and a
/// new version of Postino (#287).
const postaBanners = <Widget>[OfflineBanner(), ReconnectBanners(), ModelDownloadBanner(), AppUpdateBanner()];

/// The «N conflitti» Banner of the Posta unificata, or of one Account's inbox: «Vedi» opens the Conflitti it counts.
Widget conflictsBanner({String? accountId}) => ConflictsBanner(
  accountId: accountId,
  onOpen: () => unawaited(
    Routefly.push<void>(
      Uri(path: routePaths.conflitti, queryParameters: accountId == null ? null : {'accountId': accountId}).toString(),
    ),
  ),
);

/// The drawer of the Posta views, with the open Account ([accountId]) and Etichetta ([labelId]).
Widget postaDrawer({String? accountId, String? labelId}) => PostaDrawer(
  accountId: accountId,
  labelId: labelId,
  onOpenUnified: () => Routefly.navigate(routePaths.posta.path),
  onOpenAccount: (id) => _openFromPosta(routePaths.posta.$accountId.path.changes({'accountId': id})),
  onOpenLabel: (id) =>
      _openFromPosta(routePaths.posta.$accountId.etichetta.$labelId.changes({'accountId': accountId!, 'labelId': id})),
  onOpenDrafts: (id) => _openFromPosta(
    routePaths.posta.$accountId.etichetta.$labelId.changes({'accountId': id, 'labelId': draftLabelId}),
  ),
  onOpenSent: (id) =>
      _openFromPosta(routePaths.posta.$accountId.etichetta.$labelId.changes({'accountId': id, 'labelId': sentLabelId})),
  onOpenSettings: () => unawaited(Routefly.push<void>(routePaths.impostazioni.path)),
  onReportProblem: reportProblem,
);

void _openFromPosta(String path) => Routefly.navigate(path);
