import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:routefly/routefly.dart';

import '../../core/domain/message.dart' show draftLabelId, sentLabelId;
import '../../core/domain/platform_services.dart' show Clock;
import '../../core/domain/settings_repository.dart';
import '../../core/presentation/model_ready_notifier.dart';
import '../../design_system/design_system.dart';
import '../../features/account/presentation/onboarding_gate.dart';
import '../../features/posta/presentation/posta_shortcuts.dart';
import '../../features/segnalazione/presentation/crash_report_prompt.dart';
import '../../i18n/strings.g.dart';
import '../report_problem.dart';
import 'posta_routes.dart';
import 'posta_views.dart';

/// Layout of `/posta`: draws the view of the current URI itself (unified, Account, Etichetta, Conversazione),
/// so the outgoing view can fade out with its own params. The child route pages just delegate here.
/// A Conversazione, or the composer of a Bozza, opens beside (from 900) or over its list, which stays mounted: the list it was opened from.
class PostaLayout extends StatefulWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const PostaLayout({super.key});

  @override
  State<PostaLayout> createState() => _PostaLayoutState();
}

class _PostaLayoutState() extends State<PostaLayout> {
  /// The last list shown: a Conversazione stays beside it. Null before any (a deep link).
  String? _list;

  /// The Account of the list shown (null: the Posta unificata): what `/` searches in.
  String? _accountId;

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
  void initState() {
    super.initState();
    _cursor.reportProblem = reportProblem;
    // The Account of the list in front, read when the key is pressed.
    _cursor.search = () => openSearch(accountId: _accountId);
  }

  @override
  Widget build(BuildContext context) {
    // Routefly.of subscribes to route changes; the last configuration is the active route.
    final own = Routefly.of(context).route.uri.path;
    final uri = Routefly.currentUri;
    // Built from the URI, not from Routefly.query, so the outgoing view keeps its own params while it fades out.
    final PostaRoute(:list, :open, :draft, :detail, :accountId, :labelId) = PostaRoute.parse(
      uri,
      isLayout: Routefly.currentOriginalPath == own,
      last: _list,
    );
    if (detail == null) _list = list;
    _accountId = accountId;
    void back() => Routefly.navigate(list);
    // Invia: the composer closes and the Snackbar of Annulla invio shows under this layout's messenger (the
    // app's: PostaLayout outlives the composer in both layouts), so it survives the detail going away.
    void queued(String accountId, String messageId, DateTime until) {
      // The preparation may outlast the composer: go back only if the route is still this very composer. By
      // Message-ID alone: the route keeps the originating Account, which is not the sender picked in the composer.
      final now = Routefly.currentUri.pathSegments;
      if (now.length > 3 && now[2] == 'bozza' && now[3] == messageId) {
        back();
      }
      PostinoSnackbar.show(
        context,
        message: context.t.composizione.queued,
        actionLabel: context.t.composizione.undo,
        until: until,
        now: GetIt.I<Clock>().now,
        onAction: () => reopenAsDraft(accountId, messageId),
      );
    }

    // One shell above the content: only the content is replaced on navigation.
    // Above the gate: the keys work during the onboarding too (p shares the log without an Account).
    final shell = PostaShortcuts(
      cursor: _cursor,
      child: CrashReportPrompt(
        onReport: reportProblem,
        child: OnboardingGate(
          onReportProblem: reportProblem,
          child: ModelReadyNotifier(
            child: FutureBuilder<(bool?, double?)>(
              future: _saved,
              builder: (context, saved) => saved.connectionState != ConnectionState.done
                  ? const SizedBox.shrink()
                  : PostinoSidebarShell(
                      drawer: postaDrawer(accountId: accountId, labelId: labelId),
                      closeLabel: context.t.sidebar.close,
                      openLabel: context.t.sidebar.open,
                      expanded: saved.data!.$1,
                      onExpandedChanged: (expanded) =>
                          GetIt.I<SettingsRepository>().setSidebarExpanded(expanded: expanded),
                      child: PostinoSnackbarHost(
                        child: PostinoFadeThrough(
                          transitionKey: list,
                          child: PostinoListDetailLayout(
                            listWidth: _width,
                            onListWidthChanged: (w) {
                              _width = w;
                              unawaited(GetIt.I<SettingsRepository>().setListWidth(w));
                            },
                            resizeLabel: context.t.listWidth.label,
                            resizeValueLabel: (w) => context.t.listWidth.value(px: w.round()),
                            list: switch ((accountId, labelId)) {
                              (final a?, draftLabelId) => postaDraftsView(a, selected: detail, cursor: _cursor),
                              (final a?, sentLabelId) => postaSentView(a, selected: open, cursor: _cursor),
                              (final a?, final l?) => postaLabelView(a, l, selected: open, cursor: _cursor),
                              (final a?, null) => postaAccountView(a, selected: open, cursor: _cursor),
                              _ => postaUnifiedView(selected: open, cursor: _cursor),
                            },
                            detail: draft != null
                                ? postaComposerView(draft.$1, draft.$2, onClose: back, onQueued: queued)
                                : open == null
                                ? null
                                : postaConversationView(
                                    open.$1,
                                    open.$2,
                                    onBack: back,
                                    cursor: _cursor,
                                    onOpenDraft: (id) => openDraft(open.$1, id),
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
          ),
        ),
      ),
    );
    // The system's Indietro (Android) closes the open Conversazione or Bozza like its own Indietro: the detail is
    // drawn here, not pushed, so there is no page to pop (#39, a Conversazione opened from a notification).
    return BackButtonListener(
      onBackButtonPressed: () async {
        // A page pushed over it (Impostazioni) pops first.
        if (detail == null || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
        back();
        return true;
      },
      child: shell,
    );
  }
}
