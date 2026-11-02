import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/attachment_repository.dart';
import '../../../core/domain/file_size.dart';
import '../../../core/domain/html_text.dart';
import '../../../core/domain/mailbox.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/reply.dart';
import '../../../core/domain/result.dart';
import '../../../core/domain/trusted_senders_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/quoted_text.dart';
import '../domain/safe_html.dart';
import 'message_time.dart';
import 'posta_shortcuts.dart';

/// An open Conversazione, read from the database: every message newest first, the latest and the unread ones
/// expanded. Opening it marks it read and fetches what is missing; a missing body is downloaded when its
/// message expands, and retried when the network returns. HTML bodies render cleaned, their remote
/// resources blocked unless shown for the message or its sender is a Mittente fidato (ADR 0007).
/// A tap on an attachment downloads it (unless cached) and opens it in the system's app; its menu saves it (#34).
/// Rispondi, Rispondi a tutti and Inoltra (#37): the bar at the bottom acts on the last message, the menu
/// of each message on that one, `r`/`a`/`f` through [cursor] on the last; each saves a Bozza with the
/// Citazione and opens it ([onOpenDraft]). Routing is the caller's ([onBack], [onOpenDraft]).
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.accountId,
    required this.conversationId,
    required this.onBack,
    required this.onOpenDraft,
    this.cursor,
  });

  final String accountId;
  final String conversationId;
  final VoidCallback onBack;

  /// Opens the composer of the Bozza just saved, by Message-ID.
  final void Function(String messageId) onOpenDraft;
  final ListCursor? cursor;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _sync = GetIt.I<MailSync>();
  final _trust = GetIt.I<TrustedSendersRepository>();
  final _subs = <StreamSubscription<Object?>>[];

  /// Empty until the database answers: blocked meanwhile, never loaded too early.
  Set<String> _trusted = const {};

  /// A body is cleaned and split once per message and permission, not on every build.
  final _safe = <(String, bool), SafeHtml>{};
  final _parts = <(String, bool), BodyParts>{};
  final _measured = <(String, bool), SafeHtml>{};

  List<ConversationMessage>? _messages;
  Account? _account;
  List<Label> _labels = const [];

  /// Decided once per message, when it first shows up: reading it does not collapse it.
  final _expanded = <String, bool>{};
  final _loading = <String>{};
  final _failed = <String, Failure>{};

  /// Set when the missing messages could not be fetched: retried when the network returns.
  bool _hydrationFailed = false;

  /// By (message id, attachment id): the downloads running, with their progress and their Annulla,
  /// and why the last one failed.
  final _downloads =
      <(String, String), ({double done, Completer<void> cancel})>{};

  /// The failure, whether it was a Save As (Riprova repeats the same action) and whether the save itself
  /// failed, not the download before it.
  final _attachmentFailed =
      <(String, String), ({Failure failure, bool save, bool saving})>{};

  /// One Bozza per key press: a second `r` while the first is still saving does nothing.
  bool _acting = false;

  /// Inoltra could not start: the body or its attachments are not known and could not be downloaded.
  bool _forwardUnavailable = false;
  void _reply() => unawaited(_act(_Kind.reply));
  void _replyAll() => unawaited(_act(_Kind.replyAll));
  void _forward() => unawaited(_act(_Kind.forward));

  @override
  void initState() {
    super.initState();
    widget.cursor
      ?..reply = _reply
      ..replyAll = _replyAll
      ..forward = _forward;
    _subs
      ..add(
        GetIt.I<InboxRepository>()
            .watchConversation(widget.accountId, widget.conversationId)
            .listen(_onMessages),
      )
      ..add(
        GetIt.I<AccountsRepository>().watchAccounts().listen(
          (all) => setState(
            () => _account = all
                .where((a) => a.id == widget.accountId)
                .firstOrNull,
          ),
        ),
      )
      ..add(
        GetIt.I<InboxRepository>()
            .watchLabels(widget.accountId)
            .listen((l) => setState(() => _labels = l)),
      )
      ..add(_trust.watchTrusted().listen((t) => setState(() => _trusted = t)))
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
    // (a reply that arrived while open, too) is read: one mechanism for the opening and for later ones.
    if (first ||
        messages.any((m) => !m.message.isRead && _expanded[m.message.id]!)) {
      _open();
    }
    for (final (:message, :body) in messages) {
      // A body stored before attachments were known is downloaded again, shown meanwhile.
      if ((body == null || body.attachments == null) &&
          _expanded[message.id]! &&
          !_failed.containsKey(message.id)) {
        _fetchBody(message.id);
      }
    }
  }

  void _open() {
    _hydrationFailed = false;
    unawaited(
      _sync.openConversation(widget.accountId, widget.conversationId).then((r) {
        if (r is Err) _hydrationFailed = true;
      }),
    );
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

  /// Downloads (unless cached) then opens it in the system's app, or with [save] offers Save As.
  Future<void> _attachment(
    String messageId,
    Attachment attachment, {
    bool save = false,
  }) async {
    final key = (messageId, attachment.id);
    if (_downloads.containsKey(key)) return;
    final cancel = Completer<void>();
    setState(() {
      _downloads[key] = (done: 0, cancel: cancel);
      _attachmentFailed.remove(key);
    });
    Result<String> r = const Err(UnexpectedFailure('attachment'));
    try {
      r = await GetIt.I<AttachmentRepository>().file(
        widget.accountId,
        messageId,
        // The opened copy carries the name the chip shows.
        Attachment(
          id: attachment.id,
          name: _name(attachment),
          size: attachment.size,
          mimeType: attachment.mimeType,
        ),
        onProgress: (done) {
          if (mounted && _downloads.containsKey(key)) {
            setState(() => _downloads[key] = (done: done, cancel: cancel));
          }
        },
        cancel: cancel.future,
      );
    } finally {
      // Whatever happens, the chip leaves the download: never stuck on it.
      if (mounted) {
        setState(() {
          _downloads.remove(key);
          if (r case Err(:final failure) when failure is! CancelledFailure) {
            _attachmentFailed[key] = (
              failure: failure,
              save: save,
              saving: false,
            );
          }
        });
      }
    }
    if (!mounted) return;
    if (r case Ok(value: final path)) {
      if (!save) {
        return GetIt.I<LinkOpener>().open(Uri.file(path));
      }
      try {
        await GetIt.I<FileSaver>().save(path, _name(attachment));
      } on Exception catch (e, s) {
        // A full disk, a folder it may not write to: said on the attachment, Riprova saves again.
        if (mounted) {
          setState(
            () => _attachmentFailed[key] = (
              failure: UnexpectedFailure(e, s),
              save: true,
              saving: true,
            ),
          );
        }
      }
    }
  }

  /// The attachment's name, or «Allegato senza nome» when the message gives none.
  /// The same name everywhere (chip, opened copy, Save As), with an extension from its type when it has none,
  /// so it opens in the right app (open_filex picks the app by extension only).
  String _name(Attachment a) => switch (a.name) {
    '' => '${context.t.conversazione.attachmentUntitled}${a.fallbackExtension}',
    final n when !n.contains('.') => '$n${a.fallbackExtension}',
    final n => n,
  };

  void _toggle(String id, bool hasBody) {
    final open = !_expanded[id]!;
    setState(() => _expanded[id] = open);
    if (open && !hasBody) _fetchBody(id);
    final unread = _messages!.any(
      (m) => m.message.id == id && !m.message.isRead,
    );
    if (open && unread) _open();
  }

  /// Rispondi / Rispondi a tutti / Inoltra [messageId] (the last message by default): the Bozza with the
  /// Citazione is saved, then the composer opened. A body not here yet is downloaded first. If it cannot
  /// be, Rispondi quotes the snippet; Inoltra (which needs the attachments too, unknown in rows older
  /// than database v9) makes no Bozza and says so.
  Future<void> _act(_Kind kind, {String? messageId}) async {
    final a = _account;
    final messages = _messages;
    if (_acting || a == null || messages == null || messages.isEmpty) return;
    _acting = true;
    try {
      var (:message, :body) = messageId == null
          ? messages.last
          : messages.firstWhere((m) => m.message.id == messageId);
      final forward = kind == _Kind.forward;
      if ((body == null || forward && body.attachments == null) &&
          await _sync.fetchBody(widget.accountId, message.id) is Ok) {
        // The database stream answers with the rows as they are now.
        final fresh = await GetIt.I<InboxRepository>()
            .watchConversation(widget.accountId, widget.conversationId)
            .first;
        body = fresh.where((m) => m.message.id == message.id).firstOrNull?.body;
      }
      if (!mounted) return;
      final unknown = forward && body?.attachments == null;
      setState(() => _forwardUnavailable = unknown);
      if (unknown) return;
      final html = switch (body) {
        MessageBody(kind: BodyKind.html, :final content) => content,
        MessageBody(:final content) => plainToHtml(content),
        null => plainToHtml(message.snippet),
      };
      final dateLabel = DateFormat.yMMMMEEEEd(
        Localizations.localeOf(context).languageCode,
      ).add_Hm().format(message.date.toLocal());
      final id = newMessageId(a.address);
      final draft = switch (kind) {
        _Kind.forward => buildForward(
          original: message,
          originalHtml: html,
          self: a.address,
          messageId: id,
          dateLabel: dateLabel,
          attachments: body?.attachments ?? const [],
        ),
        _ => buildReply(
          original: message,
          originalHtml: html,
          self: a.address,
          messageId: id,
          all: kind == _Kind.replyAll,
          dateLabel: dateLabel,
        ),
      };
      await _sync.saveDraft(widget.accountId, draft);
      if (mounted) widget.onOpenDraft(id);
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
    }
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    for (final d in _downloads.values) {
      if (!d.cancel.isCompleted) d.cancel.complete();
    }
    super.dispose();
  }

  List<PostinoAttachmentChip> _attachments(
    Message message,
    MessageBody? body,
    Translations$conversazione$it t,
    String locale,
  ) => [
    for (final a in body?.attachments ?? const <Attachment>[])
      if (_downloads[(message.id, a.id)] case final d)
        PostinoAttachmentChip(
          key: ValueKey('attachment-${message.id}-${a.id}'),
          name: _name(a),
          size: fileSize(a.size, locale),
          openLabel: t.attachmentOpen,
          onOpen: () => _attachment(message.id, a),
          progress: d?.done,
          progressLabel: d == null
              ? null
              : t.attachmentDownloading(percent: (d.done * 100).round()),
          cancelLabel: t.attachmentCancel,
          onCancel: () {
            if (d case (done: _, :final cancel) when !cancel.isCompleted) {
              cancel.complete();
            }
          },
          error: switch (_attachmentFailed[(message.id, a.id)]) {
            null => null,
            (failure: OfflineFailure(), save: _, saving: _) =>
              t.attachmentOffline,
            (failure: _, save: _, saving: true) => t.attachmentSaveFailed,
            _ => t.attachmentFailed,
          },
          retryLabel: t.retry,
          onRetry: () => _attachment(
            message.id,
            a,
            save: _attachmentFailed[(message.id, a.id)]?.save ?? false,
          ),
          moreLabel: t.attachmentMore,
          saveLabel: t.attachmentSave,
          onSave: GetIt.I<FileSaver>().available
              ? () => _attachment(message.id, a, save: true)
              : null,
        ),
  ];

  bool _allowRemote(Message message) =>
      _trusted.contains(normalizeAddress(message.from)) ||
      _trust.shownOnce(widget.accountId, message.id);

  /// The cleaned HTML of a message, null for plain text.
  SafeHtml? _html(Message message, MessageBody body) {
    if (body.kind == BodyKind.testo) return null;
    final allow = _allowRemote(message);
    return _safe[(message.id, allow)] ??= prepareHtml(
      body.content,
      allowRemote: allow,
    );
  }

  /// Body, signature and quote of a message (ThreadView), after the cleaning.
  BodyParts _split(Message message, MessageBody body) {
    final safe = _html(message, body);
    return _parts[(message.id, safe != null && _allowRemote(message))] ??=
        safe == null ? splitText(body.content) : splitHtml(safe.html);
  }

  /// One part of a body: HTML on its cartoncino, sized to its own width, or text.
  Widget _part(
    String content,
    BodyKind kind,
    Message message, {
    bool quiet = false,
  }) {
    if (kind == BodyKind.testo) {
      return PostinoMessageBody(text: content, quiet: quiet);
    }
    // Already clean: this only measures the part's own fixed width.
    final allow = _allowRemote(message);
    final part = _measured[(content, allow)] ??= prepareHtml(
      content,
      allowRemote: allow,
    );
    return PostinoHtmlCard(
      html: part.html,
      contentWidth: part.width,
      quiet: quiet,
      onTapUrl: (url) {
        // Web and mail only: a `file:` link in a message must never open (or hand out) a local file.
        if (Uri.tryParse(url) case final uri?
            when ['http', 'https', 'mailto'].contains(uri.scheme)) {
          unawaited(GetIt.I<LinkOpener>().open(uri));
        }
      },
    );
  }

  /// Under the header, above the body (not for a Mittente fidato: nothing is blocked then).
  List<Widget> _notices(
    Message message,
    MessageBody? body,
    Translations$conversazione$it t,
  ) {
    if (body == null || !(_html(message, body)?.blocked ?? false)) {
      return const [];
    }
    return [
      PostinoBanner(
        tone: PostinoBannerTone.info,
        icon: PostinoIcons.image,
        title: t.imagesBlocked,
        message: t.imagesBlockedBody,
        spaced: false,
        actionLabel: t.showImages,
        onAction: () =>
            setState(() => _trust.showOnce(widget.accountId, message.id)),
        secondaryActionLabel: t.alwaysFromSender,
        onSecondaryAction: () => unawaited(_trust.trust(message.from)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.conversazione;
    final messages = _messages;
    final a = _account;
    final now = GetIt.I<Clock>().now();
    final accountRef = a == null
        ? null
        : (color: PostinoAccountColor.values[a.color], initial: a.initial);
    final locale = Localizations.localeOf(context).languageCode;
    String name(String entry) {
      final m = parseMailbox(entry);
      return m.address.toLowerCase() == a?.address.toLowerCase()
          ? t.me
          : m.name ?? m.address;
    }

    // Oldest first: a signature folds when an earlier message already had it.
    final parts = <String, BodyParts>{
      for (final (:message, :body) in messages ?? const <ConversationMessage>[])
        if (body != null) message.id: _split(message, body),
    };
    final flags = repeatedSignatures(parts.values.map((p) => p.signatureKey));
    final shown = {
      for (final (i, MapEntry(:key, :value)) in parts.entries.indexed)
        key: foldBody(value, repeated: flags[i]),
    };
    return PostinoSinglePaneLayout(
      // Beside the list (two panes) there is nothing to go back to: Esc closes it, no button.
      appBar: PostinoAppBar(
        title: '',
        onBack:
            MediaQuery.sizeOf(context).width >= PostinoSize.breakpointListDetail
            ? null
            : widget.onBack,
      ),
      body: messages == null || messages.isEmpty || a == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PostinoThreadView(
                    subject: messages.first.message.subject,
                    account: (
                      color: PostinoAccountColor.values[a.color],
                      initial: a.initial,
                    ),
                    accountName: a.name,
                    importantLabel:
                        messages.any(
                          (m) => m.message.labelIds.contains('IMPORTANT'),
                        )
                        ? t.important
                        : null,
                    labels: [
                      for (final l in _labels)
                        if (l.kind == LabelKind.etichetta &&
                            messages.any(
                              (m) => m.message.labelIds.contains(l.id),
                            ))
                          l.name,
                    ],
                    messages: [
                      for (final (:message, :body) in messages.reversed)
                        PostinoThreadMessage(
                          key: ValueKey('message-${message.id}'),
                          sender: message.fromName ?? message.from,
                          address: message.fromName == null
                              ? null
                              : message.from,
                          time: messageTime(
                            message.date,
                            now,
                            locale,
                            context.t.list.yesterday,
                          ),
                          preview: message.snippet,
                          recipients: message.cc.isEmpty
                              ? t.to(
                                  recipients: message.to.map(name).join(', '),
                                )
                              : t.toCc(
                                  recipients: message.to.map(name).join(', '),
                                  cc: message.cc.map(name).join(', '),
                                ),
                          details: [
                            PostinoMessageDetail(
                              t.from,
                              formatMailbox((
                                name: message.fromName,
                                address: message.from,
                              )),
                            ),
                            PostinoMessageDetail(
                              t.toLabel,
                              message.to.join(', '),
                            ),
                            if (message.cc.isNotEmpty)
                              PostinoMessageDetail(t.cc, message.cc.join(', ')),
                            PostinoMessageDetail(
                              t.date,
                              DateFormat.yMMMMEEEEd(locale)
                                  .add_Hm()
                                  .format(message.date.toLocal()),
                            ),
                            PostinoMessageDetail(
                              t.receivedOn,
                              a.address,
                              account: accountRef,
                            ),
                          ],
                          notices: _notices(message, body, t),
                          actions: PostinoMenu(
                            buttonKey: ValueKey(
                              'message-actions-${message.id}',
                            ),
                            label: t.messageActions,
                            items: [
                              for (final (kind, label) in [
                                (_Kind.reply, t.reply),
                                (_Kind.replyAll, t.replyAll),
                                (_Kind.forward, t.forward),
                              ])
                                PostinoMenuItem(
                                  key: ValueKey(
                                    'message-${kind.name}-${message.id}',
                                  ),
                                  label: label,
                                  onPressed: () => unawaited(
                                    _act(kind, messageId: message.id),
                                  ),
                                ),
                            ],
                          ),
                          unread: !message.isRead,
                          expanded: _expanded[message.id]!,
                          // A body without its attachments known (stored before v9) is downloaded again too.
                          onToggle: () => _toggle(
                            message.id,
                            body != null && body.attachments != null,
                          ),
                          quoteLabel: t.showQuoted,
                          attachments: _attachments(message, body, t, locale),
                          signature: switch ((
                            body,
                            shown[message.id]?.signature,
                          )) {
                            (final b?, final s?) => _part(
                              s,
                              b.kind,
                              message,
                              quiet: true,
                            ),
                            _ => null,
                          },
                          quote: switch ((body, shown[message.id]?.folded)) {
                            (final b?, final q?) => _part(
                              q,
                              b.kind,
                              message,
                              quiet: true,
                            ),
                            _ => null,
                          },
                          body: switch ((body, _failed[message.id])) {
                            (final b?, _) => _part(
                              shown[message.id]!.body,
                              b.kind,
                              message,
                            ),
                            (null, final f?) => PostinoMessageBody.missing(
                              key: const ValueKey('body-missing'),
                              note: f is OfflineFailure ? t.offline : t.failed,
                              actionLabel: t.retry,
                              onAction: () => _fetchBody(message.id),
                            ),
                            (null, null) => PostinoMessageBody.missing(
                              note: t.loading,
                            ),
                          },
                        ),
                    ],
                  ),
                ),
                // Under the thread, always in view: on the last message (ADR 0014: r, a, f).
                if (_forwardUnavailable)
                  PostinoBanner(
                    key: const ValueKey('forward-unavailable'),
                    tone: PostinoBannerTone.warning,
                    title: t.forwardUnavailable,
                  ),
                PostinoActionBar(
                  children: [
                    PostinoButton(
                      key: const ValueKey('reply'),
                      label: t.reply,
                      onPressed: _reply,
                    ),
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
    );
  }
}

enum _Kind { reply, replyAll, forward }
