import 'package:flutter/foundation.dart';

import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';
import '../mail_store.dart';
import 'account_gate.dart';
import 'account_queue.dart';
import 'provider_factory.dart';
import 'queue_replay.dart';

/// What the UI asks of the Provider on demand, outside the sync: a whole Conversazione, a body, an attachment.
/// Nothing is written once the Account's removal started (#174).
class OnDemandFetcher(
  final MailStore _store,
  final AccountGate _gate,
  final AccountQueue _queue,
  final QueueReplay _replay,
) {
  Future<Result<void>> openConversation(String accountId, String conversationId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = providerFor(account);
    // Read here at once, offline too; the Provider hears it from the queue.
    await _store.markConversationRead(accountId, conversationId);
    // Fetched inside the Account's slot: no sync can apply a newer change between the fetch and the apply.
    // ponytail: the opening waits behind a running sync (an initial one too); a cursor check on apply if that ever hurts.
    final fetched = await _queue.run(accountId, () async {
      // Inviati and messages older than the sync window are not in the database yet.
      // ponytail: refetched on every opening (one request); remember complete Conversazioni if the quota ever matters.
      final fetched = await _fetchConversation(accountId, provider, conversationId);
      if (fetched case Ok(:final value)) {
        await _store.applyPage(accountId, value, const {});
        await _store.markConversationRead(accountId, conversationId);
      }
      // Its own replay, after any batch a sync fetched before the read: it sends every intent queued so far.
      await _replay.run(accountId, provider);
      return fetched;
    });
    return switch (fetched) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void>> completeConversation(String accountId, String conversationId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    final provider = providerFor(account);
    // Unlike openConversation it does not mark the Conversazione read.
    final fetched = await _queue.run(accountId, () async {
      final fetched = await _fetchConversation(accountId, provider, conversationId);
      if (fetched case Ok(:final value)) await _store.applyPage(accountId, value, const {});
      return fetched;
    });
    return switch (fetched) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void>> fetchBody(String accountId, String messageId) async {
    final account = await _gate.find(accountId);
    if (account == null) return const Err(NotFoundFailure());
    switch (await providerFor(account).fetchBody(messageId)) {
      case Ok(:final value):
        // Removed while the body downloaded (#174): nothing of it is written again.
        if (_gate.removed(accountId)) return const Err(NotFoundFailure());
        await _store.saveBody(accountId, messageId, value);
        return const Ok(null);
      case Err(:final failure):
        debugPrint('[sync] $accountId: body $messageId failed, $failure');
        return Err(failure);
    }
  }

  Future<Result<AttachmentBytes>> fetchAttachment(
    String accountId,
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  }) async {
    final account = await _gate.find(accountId);
    if (account == null || _gate.removed(accountId)) return const Err(NotFoundFailure());
    final fetched = await providerFor(account)
        .fetchAttachment(messageId, attachmentId, onProgress: onProgress, cancel: cancel);
    // Removed during the download (#174): the cache does not keep it.
    return _gate.removed(accountId) ? const Err(NotFoundFailure()) : fetched;
  }

  /// The whole Conversazione from the Provider, unless the Account's pause holds; a rate limit pauses it.
  /// [NotFoundFailure] once the Account's removal started (#174), also when it starts during the fetch: the caller
  /// writes nothing then.
  Future<Result<List<Message>>> _fetchConversation(String id, MailProvider provider, String conversationId) async {
    if (_gate.removed(id)) return const Err(NotFoundFailure());
    if (_gate.paused(id)) return Err(RateLimitFailure(retryAfter: _gate.pausedUntil(id)));
    final fetched = await provider.fetchConversation(conversationId);
    if (_gate.removed(id)) return const Err(NotFoundFailure());
    if (fetched case Err(failure: RateLimitFailure(:final retryAfter?))) _gate.pause(id, retryAfter);
    return fetched;
  }
}
