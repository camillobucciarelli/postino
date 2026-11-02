import 'dart:async';
import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/mail_provider.dart';
import '../domain/mail_sync.dart';
import '../domain/message.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'gmail/gmail_provider.dart';
import 'mail_store.dart';

/// Polling period: the change signal watches only the inbox, so the poll also brings Bozze and the rest (ADR 0008).
const pollEvery = Duration(seconds: 60);

/// Pause in the edits after which a Bozza goes to the Provider (#35).
const draftDebounce = Duration(seconds: 5);

/// Sync engine (ADR 0008): initial sync once per Account, then incremental from the saved cursor
/// whenever the change signal fires, every [pollEvery], and when the network returns.
@lazySingleton
class SyncEngine implements MailSync {
  SyncEngine(this._store, this._clock, this._connectivity);
  final MailStore _store;
  final Clock _clock;
  final Connectivity _connectivity;

  final _subs = <StreamSubscription<Object?>>[];
  final _signals = <String, StreamSubscription<ChangeSignal>>{};

  /// Accounts the Provider blocked until a given time: no sync before it.
  final _pausedUntil = <String, DateTime>{};

  /// Per Account, the tail of its serial queue: syncs, Conversazione hydrations and replays
  /// run one after the other, so none applies a Provider answer older than one already applied.
  final _tail = <String, Future<void>>{};

  /// Per Account, the sync waiting in the queue: more requests join it instead of piling up.
  final _queuedSync = <String, Future<void>>{};

  /// Per Account, the ticker that sends its Bozze once the edits pause.
  final _draftTimers = <String, StreamSubscription<void>>{};

  /// Starts listening to change signals, the poll and the network, then syncs everything.
  void start() {
    _subs
      ..add(_store.watchAccounts().listen(_watchSignals))
      ..add(_clock.every(pollEvery).listen((_) => _poll()))
      ..add(
        _connectivity.onChanged.listen((online) {
          if (online) unawaited(syncAll());
        }),
      );
    unawaited(syncAll());
  }

  Future<void> stop() async {
    await Future.wait([
      for (final s in [..._subs, ..._signals.values, ..._draftTimers.values])
        s.cancel(),
    ]);
    _subs.clear();
    _signals.clear();
    _draftTimers.clear();
  }

  @override
  Future<void> syncAll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        // A Da ricollegare Account stops syncing until the user consents again.
        if (account.status == AccountStatus.attivo) _sync(account),
    ]);
  }

  @override
  Future<Result<void>> openConversation(
    String accountId,
    String conversationId,
  ) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = _provider(account);
    // Read here at once, offline too; the Provider hears it from the queue.
    await _store.markConversationRead(accountId, conversationId);
    // Fetched inside the Account's slot: no sync can apply a newer change between the fetch and the apply.
    // ponytail: the opening waits behind a running sync (an initial one too); a cursor check on apply if that ever hurts.
    final fetched = await _serial(accountId, () async {
      // Inviati and messages older than the sync window are not in the database yet.
      // ponytail: refetched on every opening (one request); remember complete Conversazioni if the quota ever matters.
      final fetched = await provider.fetchConversation(conversationId);
      if (fetched case Ok(:final value)) {
        await _store.applyPage(accountId, value, const {});
        await _store.markConversationRead(accountId, conversationId);
      }
      // Its own replay, after any batch a sync fetched before the read: it sends every intent queued so far.
      await _replay(accountId, provider);
      return fetched;
    });
    return switch (fetched) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> fetchBody(String accountId, String messageId) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    switch (await _provider(account).fetchBody(messageId)) {
      case Ok(:final value):
        await _store.saveBody(accountId, messageId, value);
        return const Ok(null);
      case Err(:final failure):
        debugPrint('[sync] $accountId: body $messageId failed, $failure');
        return Err(failure);
    }
  }

  @override
  Future<void> saveDraft(String accountId, OutgoingMessage draft) async {
    await _store.saveDraft(
      accountId,
      draft,
      updatedAt: _clock.now().millisecondsSinceEpoch,
    );
    // Swapped with no await in between: two saves in a row must not both keep a timer.
    final old = _draftTimers.remove(accountId);
    _draftTimers[accountId] = _clock
        .every(draftDebounce)
        .listen((_) => unawaited(flushDrafts(accountId)));
    await old?.cancel();
  }

  @override
  Future<void> flushDrafts(String accountId) async {
    await _draftTimers.remove(accountId)?.cancel();
    final account = await _account(accountId);
    // Da ricollegare: the queue waits for the reconnection, which syncs (and replays) again.
    if (account == null || account.status != AccountStatus.attivo) return;
    await _serial(accountId, () async {
      await _replay(accountId, _provider(account), flush: true);
    });
  }

  @override
  Future<Result<OutgoingMessage>> openDraft(
    String accountId,
    String messageId,
  ) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final local = await _store.localDraft(accountId, messageId);
    final remote = await _store.remoteDraft(accountId, messageId);
    // The local copy, unless the Provider has a newer one and nothing here is waiting to go:
    // then it was edited elsewhere since, and the Provider's version is taken over.
    // ponytail: by the device clock against the Provider's date; a clock far ahead keeps the local copy.
    if (local != null &&
        (local.pending ||
            remote == null ||
            remote.message.date.millisecondsSinceEpoch <= local.updatedAt)) {
      return Ok(local.draft);
    }
    if (remote == null) return const Err(NotFoundFailure());
    var body = remote.body;
    if (body == null) {
      switch (await _provider(account).fetchBody(remote.message.id)) {
        case Ok(:final value):
          body = value;
          await _store.saveBody(accountId, remote.message.id, value);
        case Err(:final failure):
          // Offline: what we have.
          return local != null ? Ok(local.draft) : Err(failure);
      }
    }
    // The save replaces the whole message and the adapters only write text.
    // ponytail: refused; keep the attachments in the adapters if people ask.
    if (body.attachments?.isNotEmpty ?? false) {
      return const Err(DraftWithAttachmentsFailure());
    }
    final draft = OutgoingMessage(
      messageId: messageId,
      from: account.address,
      to: remote.message.to,
      cc: remote.message.cc,
      bcc: remote.message.bcc,
      subject: remote.message.subject,
      body: switch (body.kind) {
        BodyKind.html => body.content,
        BodyKind.testo => _plainToHtml(body.content),
      },
    );
    await _store.adoptDraft(
      accountId,
      draft,
      updatedAt: remote.message.date.millisecondsSinceEpoch,
    );
    return Ok(draft);
  }

  static const _escape = HtmlEscape(HtmlEscapeMode.element);

  /// A paragraph per blank-line block, `<br>` for the other line breaks.
  static String _plainToHtml(String text) => text.trim().isEmpty
      ? '<p></p>'
      : [
          for (final p
              in text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n')))
            if (p.trim().isNotEmpty)
              '<p>${_escape.convert(p.trim()).replaceAll('\n', '<br>')}</p>',
        ].join();

  /// Straight from the Provider, outside the Account's serial queue: a download never waits behind a sync.
  Future<Result<AttachmentBytes>> fetchAttachment(
    String accountId,
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final account = await _account(accountId);
    if (account == null) return const Err(NotFoundFailure());
    return _provider(account).fetchAttachment(
      messageId,
      attachmentId,
      onProgress: onProgress,
      cancel: cancel,
    );
  }

  Future<Account?> _account(String id) async =>
      (await _store.accounts()).where((a) => a.id == id).firstOrNull;

  /// Runs [op] after everything already queued for the Account; a failure does not block the queue.
  Future<T> _serial<T>(String accountId, Future<T> Function() op) {
    final run = (_tail[accountId] ?? Future<void>.value()).then((_) => op());
    _tail[accountId] = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Sends the offline queue (ADR 0008); what fails stays queued and the next poll retries it.
  /// A Bozza edited within [draftDebounce] waits for its timer, unless [flush] (leaving the composer, reconnection).
  /// Called only from inside the Account's serial queue.
  Future<void> _replay(
    String accountId,
    MailProvider provider, {
    bool flush = false,
  }) async {
    final byValue = <bool, List<String>>{};
    for (final i in await _store.pendingIntents(accountId)) {
      if (i.isRead case final read?) (byValue[read] ??= []).add(i.messageId);
    }
    for (final MapEntry(key: read, value: ids) in byValue.entries) {
      switch (await provider.setRead(ids, read: read)) {
        // Gone from the Provider: the intent is dropped in silence.
        case Ok() || Err(failure: NotFoundFailure()):
          await _store.readDone(accountId, ids, isRead: read);
        case Err(:final failure):
          debugPrint('[sync] $accountId: replay failed, $failure');
      }
    }
    for (final (:draft, :isNew, :updatedAt) in await _store.pendingDrafts(
      accountId,
    )) {
      if (!flush &&
          _clock.now().millisecondsSinceEpoch - updatedAt <
              draftDebounce.inMilliseconds) {
        continue;
      }
      switch (await provider.saveDraft(draft, isNew: isNew)) {
        case Ok():
          await _store.draftSynced(accountId, draft.messageId, updatedAt);
        // Sent or deleted elsewhere: the local edit is dropped in silence (ADR 0008).
        case Err(failure: NotFoundFailure()):
          await _store.removeDraft(accountId, draft.messageId);
        case Err(:final failure):
          debugPrint('[sync] $accountId: draft replay failed, $failure');
      }
    }
  }

  Future<void> _poll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        if (account.status == AccountStatus.attivo) _sync(account),
    ]);
  }

  /// One change-signal subscription per attivo Account.
  void _watchSignals(List<Account> accounts) {
    final attivi = {
      for (final a in accounts)
        if (a.status == AccountStatus.attivo) a.id: a,
    };
    for (final id in _signals.keys.toList()) {
      if (!attivi.containsKey(id)) {
        unawaited(_signals.remove(id)!.cancel());
      }
    }
    for (final a in attivi.values) {
      if (_signals.containsKey(a.id)) continue;
      _signals[a.id] = _provider(a).changes.listen((signal) {
        switch (signal) {
          // Up: whatever changed while it was down.
          case ChangeSignal.up || ChangeSignal.changed:
            unawaited(_sync(a));
          case ChangeSignal.down:
        }
      });
    }
  }

  /// The Account's adapter, created on first use; tests register fakes by Account id beforehand.
  MailProvider _provider(Account account) {
    final g = GetIt.I;
    if (!g.isRegistered<MailProvider>(instanceName: account.id)) {
      // ponytail: Gmail is the only Provider of step 1; Microsoft and IMAP adapters branch on account.provider at steps 4-5.
      g.registerLazySingleton<MailProvider>(
        () => GmailProvider(account.id, g(), g(), g()),
        instanceName: account.id,
      );
    }
    return g<MailProvider>(instanceName: account.id);
  }

  /// Queues a sync of the Account; requests made before it starts share it, a request while it runs queues another.
  Future<void> _sync(Account account) {
    final id = account.id;
    if (_pausedUntil[id] case final until?) {
      if (_clock.now().isBefore(until)) return Future.value();
      _pausedUntil.remove(id);
    }
    return _queuedSync[id] ??= _serial(id, () {
      _queuedSync.remove(id);
      return _syncOnce(id, _provider(account));
    });
  }

  Future<void> _syncOnce(String accountId, MailProvider provider) async {
    // The queue first, so the sync brings back what the user did offline.
    await _replay(accountId, provider);
    final cursor = await _store.cursor(accountId);
    var full = cursor == null;
    Future<Result<SyncBatch>> initial() {
      debugPrint('[sync] $accountId: initial sync start');
      return provider.initialSync(
        onPage: (messages, bodies) =>
            _store.applyPage(accountId, messages, bodies),
      );
    }

    if (!full) debugPrint('[sync] $accountId: incremental sync start');
    var result = full
        ? await initial()
        : await provider.incrementalSync(cursor);
    if (result case Err(failure: NotFoundFailure())) {
      // Expired cursor: start over.
      full = true;
      result = await initial();
    }
    switch (result) {
      case Ok(:final value):
        // The cursor is saved here, from the complete batch: pages alone never save it.
        await _store.applySync(accountId, value, fullSnapshot: full);
        debugPrint(
          '[sync] $accountId: ${full ? 'initial' : 'incremental'} sync end, '
          '${value.messages.length} messages, ${value.removedMessageIds.length} removed',
        );
      case Err(:final failure):
        debugPrint('[sync] $accountId: failed, $failure');
        if (failure case RateLimitFailure(:final retryAfter?)) {
          _pausedUntil[accountId] = retryAfter;
          debugPrint('[sync] $accountId: paused until $retryAfter');
        }
        // ponytail: a fixed retry on the next poll; exponential backoff if Providers keep refusing.
        if (failure is AuthFailure) {
          await _store.setStatus(accountId, AccountStatus.daRicollegare);
        }
    }
  }
}

@module
abstract class SyncModule {
  /// The UI sees the engine only through [MailSync].
  @lazySingleton
  MailSync mailSync(SyncEngine engine) => engine;
}
