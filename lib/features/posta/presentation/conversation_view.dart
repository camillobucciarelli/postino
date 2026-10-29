import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'body_text.dart';
import 'message_time.dart';

/// An open Conversazione, read from the database: every message oldest first, the latest and the unread ones
/// expanded. Opening it marks it read and fetches what is missing; a missing body is downloaded when its
/// message expands, and retried when the network returns. Routing is the caller's ([onBack]).
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
  final _subs = <StreamSubscription<Object?>>[];

  List<ConversationMessage>? _messages;
  Account? _account;

  /// Decided once per message, when it first shows up: reading it does not collapse it.
  final _expanded = <String, bool>{};
  final _loading = <String>{};
  final _failed = <String, Failure>{};

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
        GetIt.I<Connectivity>().onChanged.listen((online) {
          if (online) _failed.keys.toList().forEach(_fetchBody);
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
          // The latest, at first sight only: messages fetched later are older ones.
          () => !message.isRead || (first && i == messages.length - 1),
        );
      }
    });
    // Only now: the expansion above saw which messages were unread.
    if (first) {
      unawaited(
        _sync.openConversation(widget.accountId, widget.conversationId),
      );
    }
    for (final (:message, :body) in messages) {
      if (body == null &&
          _expanded[message.id]! &&
          !_failed.containsKey(message.id)) {
        _fetchBody(message.id);
      }
    }
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
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.conversazione;
    final messages = _messages;
    final a = _account;
    final now = GetIt.I<Clock>().now();
    final locale = Localizations.localeOf(context).languageCode;
    return PostinoSinglePaneLayout(
      appBar: PostinoAppBar(title: '', onBack: widget.onBack),
      body: messages == null || messages.isEmpty || a == null
          ? const SizedBox.shrink()
          : PostinoThreadView(
              subject: messages.first.message.subject,
              account: (
                color: PostinoAccountColor.values[a.color],
                initial: a.initial,
              ),
              accountName: a.name,
              messages: [
                for (final (:message, :body) in messages)
                  PostinoThreadMessage(
                    key: ValueKey('message-${message.id}'),
                    sender: message.from,
                    time: messageTime(
                      message.date,
                      now,
                      locale,
                      context.t.list.yesterday,
                    ),
                    preview: message.snippet,
                    recipients: t.to(recipients: message.to.join(', ')),
                    unread: !message.isRead,
                    expanded: _expanded[message.id]!,
                    onToggle: () => _toggle(message.id, body != null),
                    body: switch ((body, _failed[message.id])) {
                      (final b?, _) => PostinoMessageBody(text: bodyText(b)),
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
