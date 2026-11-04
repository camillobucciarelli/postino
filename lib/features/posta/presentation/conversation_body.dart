import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart' show ConversationView;

import '../../../core/domain/account.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mailbox.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../core/domain/trusted_senders_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/quoted_text.dart';
import '../domain/reply_kind.dart';
import '../domain/safe_html.dart';
import 'attachment_actions.dart';
import 'attachment_chips.dart';
import 'message_time.dart';

/// The thread of an open Conversazione, newest first: each message with its details, its menu (Rispondi,
/// Rispondi a tutti, Inoltra: [onAct]), its body split into body, signature and quote, and its attachments.
/// HTML bodies render cleaned, their remote resources blocked unless shown for the message or its sender is
/// in [trusted] (ADR 0007). State, fetching and shortcuts are the [ConversationView]'s: none here (ADR 0014).
class ConversationBody extends StatefulWidget {
  const ConversationBody({
    super.key,
    required this.account,
    required this.messages,
    required this.labels,
    required this.trusted,
    required this.expanded,
    required this.failed,
    required this.attachments,
    required this.onToggle,
    required this.onFetchBody,
    required this.onAct,
  });

  final Account account;

  /// Oldest first, never empty.
  final List<ConversationMessage> messages;
  final List<Label> labels;
  final Set<String> trusted;
  final Map<String, bool> expanded;

  /// Why a body could not be downloaded, by message id.
  final Map<String, Failure> failed;
  final AttachmentActions attachments;

  /// [hasBody]: the body and its attachments are known, nothing to download.
  final void Function(String id, bool hasBody) onToggle;
  final void Function(String id) onFetchBody;
  final void Function(ReplyKind kind, String messageId) onAct;

  @override
  State<ConversationBody> createState() => _ConversationBodyState();
}

class _ConversationBodyState extends State<ConversationBody> {
  final _trust = GetIt.I<TrustedSendersRepository>();

  /// A body is cleaned and split once per message and permission, not on every build.
  final _safe = <(String, bool), SafeHtml>{};
  final _parts = <(String, bool), BodyParts>{};
  final _measured = <(String, bool), SafeHtml>{};

  bool _allowRemote(Message message) =>
      widget.trusted.contains(normalizeAddress(message.from)) || _trust.shownOnce(widget.account.id, message.id);

  /// The cleaned HTML of a message, null for plain text.
  SafeHtml? _html(Message message, MessageBody body) {
    if (body.kind == BodyKind.testo) return null;
    final allow = _allowRemote(message);
    return _safe[(message.id, allow)] ??= prepareHtml(body.content, allowRemote: allow);
  }

  /// Body, signature and quote of a message (ThreadView), after the cleaning.
  BodyParts _split(Message message, MessageBody body) {
    final safe = _html(message, body);
    return _parts[(message.id, safe != null && _allowRemote(message))] ??= safe == null
        ? splitText(body.content)
        : splitHtml(safe.html);
  }

  /// One part of a body: HTML on its cartoncino, sized to its own width, or text.
  Widget _part(String content, BodyKind kind, Message message, {bool quiet = false}) {
    if (kind == BodyKind.testo) {
      return PostinoMessageBody(text: content, quiet: quiet);
    }
    // Already clean: this only measures the part's own fixed width.
    final allow = _allowRemote(message);
    final part = _measured[(content, allow)] ??= prepareHtml(content, allowRemote: allow);
    return PostinoHtmlCard(
      html: part.html,
      contentWidth: part.width,
      quiet: quiet,
      onTapUrl: (url) {
        // Web and mail only: a `file:` link in a message must never open (or hand out) a local file.
        if (Uri.tryParse(url) case final uri? when ['http', 'https', 'mailto'].contains(uri.scheme)) {
          unawaited(GetIt.I<LinkOpener>().open(uri));
        }
      },
    );
  }

  /// Under the header, above the body (not for a Mittente fidato: nothing is blocked then).
  List<Widget> _notices(Message message, MessageBody? body, Translations$conversazione$it t) {
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
        onAction: () => setState(() => _trust.showOnce(widget.account.id, message.id)),
        secondaryActionLabel: t.alwaysFromSender,
        onSecondaryAction: () => unawaited(_trust.trust(message.from)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.conversazione;
    final messages = widget.messages;
    final a = widget.account;
    final now = GetIt.I<Clock>().now();
    final accountRef = (color: PostinoAccountColor.values[a.color], initial: a.initial);
    final locale = Localizations.localeOf(context).languageCode;
    String name(String entry) {
      final m = parseMailbox(entry);
      return m.address.toLowerCase() == a.address.toLowerCase() ? t.me : m.name ?? m.address;
    }

    // Oldest first: a signature folds when an earlier message already had it.
    final parts = <String, BodyParts>{
      for (final (:message, :body) in messages)
        if (body != null) message.id: _split(message, body),
    };
    final flags = repeatedSignatures(parts.values.map((p) => p.signatureKey));
    final shown = {
      for (final (i, MapEntry(:key, :value)) in parts.entries.indexed) key: foldBody(value, repeated: flags[i]),
    };
    return PostinoThreadView(
      subject: messages.first.message.subject,
      account: accountRef,
      accountName: a.name,
      importantLabel: messages.any((m) => m.message.labelIds.contains('IMPORTANT')) ? t.important : null,
      labels: [
        for (final l in widget.labels)
          if (l.kind == LabelKind.etichetta && messages.any((m) => m.message.labelIds.contains(l.id))) l.name,
      ],
      messages: [
        for (final (:message, :body) in messages.reversed)
          PostinoThreadMessage(
            key: ValueKey('message-${message.id}'),
            sender: message.fromName ?? message.from,
            address: message.fromName == null ? null : message.from,
            time: messageTime(message.date, now, locale, context.t.list.yesterday),
            preview: message.snippet,
            recipients: message.cc.isEmpty
                ? t.to(recipients: message.to.map(name).join(', '))
                : t.toCc(recipients: message.to.map(name).join(', '), cc: message.cc.map(name).join(', ')),
            details: [
              PostinoMessageDetail(t.from, formatMailbox((name: message.fromName, address: message.from))),
              PostinoMessageDetail(t.toLabel, message.to.join(', ')),
              if (message.cc.isNotEmpty) PostinoMessageDetail(t.cc, message.cc.join(', ')),
              PostinoMessageDetail(t.date, DateFormat.yMMMMEEEEd(locale).add_Hm().format(message.date.toLocal())),
              PostinoMessageDetail(t.receivedOn, a.address, account: accountRef),
            ],
            notices: _notices(message, body, t),
            actions: PostinoMenu(
              buttonKey: ValueKey('message-actions-${message.id}'),
              label: t.messageActions,
              items: [
                for (final (kind, label) in [
                  (ReplyKind.reply, t.reply),
                  (ReplyKind.replyAll, t.replyAll),
                  (ReplyKind.forward, t.forward),
                ])
                  PostinoMenuItem(
                    key: ValueKey('message-${kind.name}-${message.id}'),
                    label: label,
                    onPressed: () => widget.onAct(kind, message.id),
                  ),
              ],
            ),
            unread: !message.isRead,
            expanded: widget.expanded[message.id]!,
            // A body without its attachments known (stored before v9) is downloaded again too.
            onToggle: () => widget.onToggle(message.id, body != null && body.attachments != null),
            quoteLabel: t.showQuoted,
            attachments: attachmentChips(widget.attachments, message, body, t, locale),
            signature: switch ((body, shown[message.id]?.signature)) {
              (final b?, final s?) => _part(s, b.kind, message, quiet: true),
              _ => null,
            },
            quote: switch ((body, shown[message.id]?.folded)) {
              (final b?, final q?) => _part(q, b.kind, message, quiet: true),
              _ => null,
            },
            body: switch ((body, widget.failed[message.id])) {
              (final b?, _) => _part(shown[message.id]!.body, b.kind, message),
              (null, final f?) => PostinoMessageBody.missing(
                key: const ValueKey('body-missing'),
                note: f is OfflineFailure ? t.offline : t.failed,
                actionLabel: t.retry,
                onAction: () => widget.onFetchBody(message.id),
              ),
              (null, null) => PostinoMessageBody.missing(note: t.loading),
            },
          ),
      ],
    );
  }
}
