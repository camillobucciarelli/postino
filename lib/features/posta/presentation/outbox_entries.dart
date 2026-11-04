import 'dart:async';

import 'package:get_it/get_it.dart';

import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/html_text.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart' show Message, sentLabelId;
import '../../../core/domain/platform_services.dart' show Clock, Connectivity;

/// Each Bozza as a row whose Conversazione is its Message-ID: opening it opens the composer, not a thread.
// ponytail: the rows restart on every Accounts change (rare); a combineLatest if the list flickers.
Stream<List<InboxEntry>> draftEntries(String accountId, InboxRepository r) =>
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

/// The outbox rows first, newest first, then the sent messages. The state sits before the preview:
/// «In attesa d'invio» within the window or online, «In uscita, in attesa di rete» once the window passed offline,
/// «Invio non riuscito» when the Provider refused it for good.
// ponytail: the rows recompute on every outbox change (the failed attempt offline is one), not on the clock: a row
// may read «In attesa d'invio» for the seconds the send takes, then it leaves the outbox.
Stream<List<InboxEntry>> sentEntries(
  String accountId,
  InboxRepository r, {
  required String waiting,
  required String offline,
  required String failed,
}) => _latest(
  _latest(GetIt.I<AccountsRepository>().watchAccounts(), _connectivity(), (accounts, online) => (accounts, online)),
  _latest(r.watchOutbox(accountId), r.watchMessages(accountId, sentLabelId), (outbox, sent) => (outbox, sent)),
  (context, lists) {
    final (accounts, online) = context;
    final (outbox, sent) = lists;
    final now = GetIt.I<Clock>().now().millisecondsSinceEpoch;
    String state({required bool refused, required int sendAfter}) => refused
        ? failed
        : sendAfter > now || online
        ? waiting
        : offline;
    return [
      for (final a in accounts.where((a) => a.id == accountId))
        for (final OutgoingEntry(message: m, :sendAfter, failed: refused) in outbox)
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
              snippet: '${state(refused: refused, sendAfter: sendAfter)} · ${listSnippet(m.body)}',
              // The end of the window: the time it is listed under until the Provider dates it.
              date: DateTime.fromMillisecondsSinceEpoch(sendAfter, isUtc: true),
            ),
            account: a,
            count: 1,
            unread: false,
            status: state(refused: refused, sendAfter: sendAfter),
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
