import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/mailbox.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../core/domain/trusted_senders_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/quoted_text.dart';
import '../domain/safe_html.dart';
import 'message_time.dart';

/// An open Conversazione, read from the database: every message newest first, the latest and the unread ones
/// expanded. Opening it marks it read and fetches what is missing; a missing body is downloaded when its
/// message expands, and retried when the network returns. HTML bodies render cleaned, their remote
/// resources blocked unless shown for the message or its sender is a Mittente fidato (ADR 0007).
/// Routing is the caller's ([onBack]).
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.accountId,
    required this.conversationId,
    required this.onBack,
  });

  final String accountId;
  final String conversationId;
  final VoidCallback onBack;

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

  @override
  void initState() {
    super.initState();
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
      if (body == null &&
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

  void _toggle(String id, bool hasBody) {
    final open = !_expanded[id]!;
    setState(() => _expanded[id] = open);
    if (open && !hasBody) _fetchBody(id);
    final unread = _messages!.any(
      (m) => m.message.id == id && !m.message.isRead,
    );
    if (open && unread) _open();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

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
        if (Uri.tryParse(url) case final uri?) {
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
          : PostinoThreadView(
              subject: messages.first.message.subject,
              account: (
                color: PostinoAccountColor.values[a.color],
                initial: a.initial,
              ),
              accountName: a.name,
              importantLabel:
                  messages.any((m) => m.message.labelIds.contains('IMPORTANT'))
                  ? t.important
                  : null,
              labels: [
                for (final l in _labels)
                  if (l.kind == LabelKind.etichetta &&
                      messages.any((m) => m.message.labelIds.contains(l.id)))
                    l.name,
              ],
              messages: [
                for (final (:message, :body) in messages.reversed)
                  PostinoThreadMessage(
                    key: ValueKey('message-${message.id}'),
                    sender: message.fromName ?? message.from,
                    address: message.fromName == null ? null : message.from,
                    time: messageTime(
                      message.date,
                      now,
                      locale,
                      context.t.list.yesterday,
                    ),
                    preview: message.snippet,
                    recipients: message.cc.isEmpty
                        ? t.to(recipients: message.to.map(name).join(', '))
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
                      PostinoMessageDetail(t.toLabel, message.to.join(', ')),
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
                    unread: !message.isRead,
                    expanded: _expanded[message.id]!,
                    onToggle: () => _toggle(message.id, body != null),
                    quoteLabel: t.showQuoted,
                    signature: switch ((body, shown[message.id]?.signature)) {
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
    );
  }
}
