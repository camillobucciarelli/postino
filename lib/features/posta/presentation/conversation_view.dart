import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_notification.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../core/domain/trusted_senders_repository.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/conversation_label_intents.dart';
import '../domain/reply_draft_use_case.dart';
import '../domain/reply_kind.dart';
import 'attachment_actions.dart';
import 'conversation_acting.dart';
import 'conversation_body.dart';
import 'conversation_conflicts.dart';
import 'conversation_labels.dart';
import 'conversation_on_screen.dart';
import 'posta_shortcuts.dart';

/// An open Conversazione, read from the database: every message newest first, the latest and the unread ones
/// expanded. Opening it marks it read and fetches what is missing; a missing body is downloaded when its
/// message expands, and retried when the network returns. The thread renders in [ConversationBody], the
/// attachments act through [AttachmentActions] (#34).
/// Rispondi, Rispondi a tutti and Inoltra (#37): the bar at the bottom acts on the last message, the menu
/// of each message on that one, `r`/`a`/`f` through [cursor] on the last; each saves a Bozza with the
/// Citazione ([ReplyDraftUseCase]) and opens it ([onOpenDraft]). Routing is the caller's ([onBack], [onOpenDraft]).
class const ConversationView({
  super.key,
  required final String accountId,
  required final String conversationId,
  required final VoidCallback onBack,

  /// Opens the composer of the Bozza just saved, by Message-ID.
  required final void Function(String messageId) onOpenDraft,
  final ListCursor? cursor,

  /// The Etichetta of the view it is opened from: from any but the Cestino or Spam, the messages in the Cestino or
  /// Spam are neither shown nor marked read.
  final String view = inboxLabelId,
}) extends StatefulWidget {
  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState()
    extends State<ConversationView>
    with AccountsSignal, ConversationOnScreen, ConversationActing {
  final _sync = GetIt.I<MailSync>();
  final _replyDraft = GetIt.I<ReplyDraftUseCase>();
  final _subs = <StreamSubscription<Object?>>[];
  late final _attachments = AttachmentActions(widget.accountId, () => setState(() {}));

  /// Empty until the database answers: blocked meanwhile, never loaded too early.
  Set<String> _trusted = const {};

  List<ConversationMessage>? _messages;
  Account? get _account => accounts.value.value?.where((a) => a.id == widget.accountId).firstOrNull;
  List<Label> _labels = const [];

  /// Decided once per message, when it first shows up: reading it does not collapse it.
  final _expanded = <String, bool>{};
  final _loading = <String>{};
  final _failed = <String, Failure>{};

  /// Set when the missing messages could not be fetched: retried when the network returns.
  bool _hydrationFailed = false;

  /// One Bozza per key press: a second `r` while the first is still saving does nothing.
  bool _acting = false;

  /// Inoltra could not start: the body or its attachments are not known and could not be downloaded.
  bool _forwardUnavailable = false;
  void _reply() => unawaited(_act(ReplyKind.reply));
  void _replyAll() => unawaited(_act(ReplyKind.replyAll));
  void _forward() => unawaited(_act(ReplyKind.forward));

  /// The «Etichette» button: the picker anchors to it and gives it the focus back (`l` opens it too).
  final _labelsKey = GlobalKey();
  final _labelsFocus = FocusNode(debugLabel: 'Etichette');

  void _openLabels() {
    final anchor = _labelsKey.currentContext;
    if (anchor == null) return;
    unawaited(
      openLabelPicker(
        anchor,
        accountId: widget.accountId,
        conversationId: widget.conversationId,
        labelsAreFolders: _account?.provider.labelsAreFolders ?? false,
        returnFocus: _labelsFocus,
      ),
    );
  }

  @override
  List<ConversationMessage>? get shownMessages => _messages;

  @override
  Future<void> opening = Future.value();

  @override
  late final ConversationKey conversationKey = (accountId: widget.accountId, conversationId: widget.conversationId);

  @override
  void initState() {
    super.initState();
    widget.cursor
      ?..reply = _reply
      ..replyAll = _replyAll
      ..forward = _forward
      ..labels = _openLabels;
    _subs
      ..add(
        GetIt.I<InboxRepository>()
            .watchConversation(widget.accountId, widget.conversationId, view: widget.view)
            .listen(_onMessages),
      )
      ..add(GetIt.I<InboxRepository>().watchLabels(widget.accountId).listen((l) => setState(() => _labels = l)))
      ..add(GetIt.I<TrustedSendersRepository>().watchTrusted().listen((t) => setState(() => _trusted = t)))
      ..add(
        GetIt.I<Connectivity>().onChanged.listen((online) {
          if (!online) return;
          if (_hydrationFailed) _open();
          _failed.keys.toList().forEach(_fetchBody);
        }),
      );
  }

  void _onMessages(List<ConversationMessage> messages) {
    final first = _messages == null;
    setState(() {
      _messages = messages;
      for (final (i, (:message, body: _)) in messages.indexed) {
        _expanded.putIfAbsent(
          message.id,
          // The latest when it shows up, a deep-linked one fetched later or a newer reply too.
          () => !message.isRead || i == messages.length - 1,
        );
      }
    });
    // Only now: the expansion above saw which messages were unread. An unread one shown expanded
    // (a reply that arrived while open, too) is read: one mechanism for the opening and for later ones. Off screen
    // (background, tray, under a page) a reply stays unread, and notified, until the Conversazione is back (#210).
    if (!closing && (first || onScreen && _unreadShown)) _open();
    for (final (:message, :body) in messages) {
      // A body stored before attachments were known is downloaded again, shown meanwhile.
      if ((body == null || body.attachments == null) && _expanded[message.id]! && !_failed.containsKey(message.id)) {
        _fetchBody(message.id);
      }
    }
  }

  /// An unread message is shown expanded.
  bool get _unreadShown => _messages?.any((m) => !m.message.isRead && _expanded[m.message.id]!) ?? false;

  @override
  void onScreenAgain() {
    if (!closing && _unreadShown) _open();
  }

  void _open() {
    _hydrationFailed = false;
    // The opening brings the older messages: an Etichetta action taken meanwhile reaches them too.
    opening = GetIt.I<ConversationLabelIntents>()
        .fetch(
          conversationKey,
          () => _sync.openConversation(widget.accountId, widget.conversationId, view: widget.view),
        )
        .then((r) {
          if (r is Err) _hydrationFailed = true;
        });
    unawaited(opening);
  }

  void _fetchBody(String id) {
    if (!_loading.add(id)) return;
    setState(() => _failed.remove(id));
    unawaited(
      _sync.fetchBody(widget.accountId, id).then((r) {
        if (!mounted) return;
        setState(() {
          _loading.remove(id);
          if (r case Err(:final failure)) _failed[id] = failure;
        });
      }),
    );
  }

  void _toggle(String id, {required bool hasBody}) {
    final open = !_expanded[id]!;
    setState(() => _expanded[id] = open);
    if (open && !hasBody) _fetchBody(id);
    final unread = _messages!.any((m) => m.message.id == id && !m.message.isRead);
    if (open && unread) _open();
  }

  /// Rispondi / Rispondi a tutti / Inoltra [messageId] (the last message by default): the Bozza with the
  /// Citazione is saved, then the composer opened. A body not here yet is downloaded first; a view closed
  /// meanwhile saves nothing. If it cannot be, Rispondi quotes the snippet; Inoltra (which needs the
  /// attachments too, unknown in rows older than database v9) makes no Bozza and says so.
  Future<void> _act(ReplyKind kind, {String? messageId}) async {
    final a = _account;
    final messages = _messages;
    if (_acting || a == null || messages == null || messages.isEmpty) return;
    _acting = true;
    try {
      final source = await _replyDraft.source(
        widget.accountId,
        widget.conversationId,
        messages,
        kind,
        messageId: messageId,
      );
      if (!mounted) return;
      setState(() => _forwardUnavailable = source.unavailable);
      if (source.unavailable) return;
      // Null: the Account was removed meanwhile, there is no Bozza to open (#191).
      final id = await _replyDraft.save(a, source);
      if (id != null && mounted) widget.onOpenDraft(id);
    } finally {
      _acting = false;
    }
  }

  @override
  void dispose() {
    final cursor = widget.cursor;
    if (cursor != null) {
      if (cursor.reply == _reply) cursor.reply = null;
      if (cursor.replyAll == _replyAll) cursor.replyAll = null;
      if (cursor.forward == _forward) cursor.forward = null;
      if (cursor.labels == _openLabels) cursor.labels = null;
    }
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _attachments.dispose();
    _labelsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(builder: _content);

  Widget _content(BuildContext context) {
    final t = context.t.conversazione;
    final messages = _messages;
    final a = _account;
    final ready = messages != null && messages.isNotEmpty && a != null;
    return PostinoSinglePaneLayout(
      // Beside the list (two panes) there is nothing to go back to: Esc closes it, no button.
      appBar: PostinoAppBar(
        title: '',
        onBack: MediaQuery.sizeOf(context).width >= PostinoSize.breakpointListDetail ? null : widget.onBack,
        commands: ready ? actionCommands(context) : const [],
        moreLabel: context.t.azioni.more,
        actions: [
          if (ready)
            PostinoIconButton(
              key: _labelsKey,
              icon: PostinoIcons.tag,
              label: context.t.selettoreEtichette.button,
              focusNode: _labelsFocus,
              onPressed: _openLabels,
            ),
        ],
      ),
      // The thread fades in once it is there (#283); a thread ready at the first build is just there.
      body: PostinoFadeSwitcher(
        curve: PostinoMotion.standardDecelerate,
        child: !ready
            ? const SizedBox.shrink()
            : Column(
                key: const ValueKey('thread'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConversationConflicts(
                    accountId: widget.accountId,
                    messages: {for (final m in messages) m.message.id: m.message},
                  ),
                  Expanded(
                    child: ConversationBody(
                      account: a,
                      messages: messages,
                      labels: _labels,
                      trusted: _trusted,
                      expanded: _expanded,
                      failed: _failed,
                      attachments: _attachments,
                      onToggle: _toggle,
                      onFetchBody: _fetchBody,
                      onAct: (kind, id) => unawaited(_act(kind, messageId: id)),
                      onRemoveLabel: (label) => removeConversationLabel(context, conversationKey, [
                        for (final m in messages) m.message,
                      ], label),
                    ),
                  ),
                  // Under the thread, always in view: on the last message (ADR 0014: r, a, f). It opens and closes.
                  PostinoReveal(
                    child: _forwardUnavailable
                        ? PostinoBanner(
                            key: const ValueKey('forward-unavailable'),
                            tone: PostinoBannerTone.warning,
                            title: t.forwardUnavailable,
                          )
                        : null,
                  ),
                  PostinoActionBar(
                    children: [
                      PostinoButton(key: const ValueKey('reply'), label: t.reply, onPressed: _reply),
                      PostinoButton(
                        key: const ValueKey('reply-all'),
                        label: t.replyAll,
                        variant: PostinoButtonVariant.ghost,
                        onPressed: _replyAll,
                      ),
                      PostinoButton(
                        key: const ValueKey('forward'),
                        label: t.forward,
                        variant: PostinoButtonVariant.ghost,
                        onPressed: _forward,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
