import 'conflict.dart';
import 'draft_conflict.dart';
import 'mail_action.dart';
import 'message.dart';
import 'provider_search_page.dart';
import 'result.dart';
import 'search_query.dart';

/// What the UI may ask of the sync engine: it still reads only from the database (ADR 0003).
abstract interface class MailSync() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Syncs every attivo Account now (start, resume, network back); completes when the sync and the offline queue are done.
  Future<void> syncAll();

  /// Pull-to-refresh: joins the sync each attivo Account is already running (or has queued) instead of queuing
  /// another, and completes at the end of its sync phase; the Bozze and the outbox keep going in the background.
  Future<void> refresh();

  /// Marks the Conversazione read (locally at once, on the Provider now or when back online)
  /// and downloads its messages missing from the database (Inviati, older than 90 days);
  /// [Err] when they could not be downloaded (offline...).
  Future<Result<void>> openConversation(String accountId, String conversationId);

  /// Downloads a message body into the database; [Err] when it could not (offline...).
  Future<Result<void>> fetchBody(String accountId, String messageId);

  /// Keeps the Bozza here at once (every edit) and on the Provider after a pause in the edits,
  /// or when back online / reconnected; the same Message-ID updates the same Bozza.
  Future<void> saveDraft(String accountId, OutgoingMessage draft);

  /// Sends the Account's pending Bozze to the Provider now (on leaving the composition);
  /// completes offline or Da ricollegare too, the Bozze stay queued.
  Future<void> flushDrafts(String accountId);

  /// Queues the message (#36): it goes after `sendWindow` (Annulla invio), also offline (when the network returns)
  /// or after a restart; [SizeLimitFailure] when it is too big for the Provider, [OfflineFailure] when a forwarded
  /// attachment is neither cached nor downloadable, and nothing is queued. Ok carries the end of the Annulla window.
  Future<Result<DateTime>> send(String accountId, OutgoingMessage message);

  /// Takes the message out of the outbox within the window, or once the Provider refused it for good;
  /// null when it already went (or was never queued). The Bozza stays, so the UI can reopen it: the result is its
  /// Message-ID, [messageId] itself, or a new one when a send was already attempted (its delivery is uncertain).
  Future<String?> cancelSend(String accountId, String messageId);

  /// Sends the Account's due outbox entries now; completes offline or Da ricollegare too, they stay queued.
  Future<void> flushOutbox(String accountId);

  /// The Bozza to resume: the local one, or one of another client (its body downloaded if missing,
  /// then kept here); [NotFoundFailure] when there is none.
  Future<Result<OutgoingMessage>> openDraft(String accountId, String messageId);

  /// One attachment straight from the Provider, outside the Account's queue (a download never waits behind
  /// a sync); for the attachment cache, the UI goes through `AttachmentRepository`.
  Future<Result<AttachmentBytes>> fetchAttachment(
    String accountId,
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  });

  /// Creates the Etichetta on the Provider and lists it here; not queued: [Err] offline or Da ricollegare.
  /// Idempotent on the name: an existing Etichetta is returned.
  Future<Result<Label>> createLabel(String accountId, String name);

  /// Applies [action] to [messageIds] here at once, and on the Provider now or when back online (ADR 0008); completes
  /// offline or Da ricollegare too, the Azione stays queued. With [hold] (the Annulla window, `undoWindow`) the voci
  /// are «trattenute»: they go to the Provider only once it ends, unless [cancelAction] takes them back first.
  Future<void> act(String accountId, Iterable<String> messageIds, MailAction action, {Duration? hold});

  /// Annulla of an [act] with `hold` still running: the voci leave the queue and the messages are as before here.
  /// False when nothing was still held (the window ended, or a later Azione replaced it).
  Future<bool> cancelAction(String accountId, Iterable<String> messageIds, MailAction action);

  /// Closes the Conflitto: [keepMine] («tieni la mia») applies its Azione on the Provider again, forced, now or when
  /// back online; otherwise («tieni quella del Provider») the message takes the Provider's value here.
  Future<void> resolveConflict(Conflict conflict, {required bool keepMine});

  /// Closes the Conflitto of a Bozza (#149): [keepMine] («La tua») uploads the Bozza here, now or when back online;
  /// otherwise («Del Provider») the Bozza here takes the Provider's version.
  Future<void> resolveDraftConflict(DraftConflict conflict, {required bool keepMine});

  /// Puts the Etichetta [labelId] on the message (with [add] false, takes it off): [act] with [ApplyLabel] or
  /// [RemoveLabel].
  Future<void> setLabel(String accountId, String messageId, String labelId, {required bool add});

  /// [setLabel] on every message of a Conversazione: all queued, then a single replay.
  Future<void> setConversationLabel(String accountId, Iterable<String> messageIds, String labelId, {required bool add});

  /// Brings the whole Conversazione here (the sync window leaves older messages out) without reading it:
  /// before putting an Etichetta on all of it. [Err] offline or on a failed fetch.
  Future<Result<void>> completeConversation(String accountId, String conversationId);

  /// One page of [query] on the Account's Provider (#207), from [pageToken] (null: the first), in the Account's
  /// queue. What it found older than the sync window and not here yet is stored like the messages of an opened
  /// Conversazione: no notification, no Etichettatura automatica; it stays until the next initial sync. A recent one
  /// is left to the sync. [AuthFailure] makes the Account Da ricollegare (a Da
  /// ricollegare one is not asked), a rate limit pauses it; [NotFoundFailure] for an Account gone or being removed.
  Future<Result<ProviderSearchPage>> search(String accountId, SearchQuery query, {String? pageToken});
}
