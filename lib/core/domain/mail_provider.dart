import 'package:equatable/equatable.dart';

import 'action_outcome.dart';
import 'draft_outcome.dart';
import 'mail_action.dart';
import 'message.dart';
import 'result.dart';

/// What a sync returns: changes since the previous cursor (everything, for the initial sync).
class const SyncBatch({
  /// Opaque to the core: Gmail historyId, Graph delta token, IMAP modseq...
  required final String cursor,

  /// Messaggi nuovi o modificati.
  final List<Message> messages = const [],

  /// Every Etichetta of the Account, which replaces the stored list; null when this sync did not read them.
  final List<Label>? labels,

  /// Id (lato Provider) dei messaggi eliminati.
  final List<String> removedMessageIds = const [],

  /// Bodies downloaded with the sync, by Provider-side message id: the inbox ones (ADR 0003).
  final Map<String, MessageBody> bodies = const {},
}) extends Equatable {
  /// Crea un batch; senza argomenti le liste sono vuote e le Etichette non lette.
  this;

  @override
  List<Object?> get props => [cursor, messages, labels, removedMessageIds, bodies];
}

/// A page of the initial sync, delivered as soon as it is fetched so the UI fills up progressively.
typedef SyncPage = Future<void> Function(List<Message> messages, Map<String, MessageBody> bodies);

/// What the change signal reports: it came [up], something [changed], or it went [down].
/// While it is down the sync engine falls back to polling (ADR 0008).
/// Stato del segnale di cambiamento.
enum ChangeSignal() {
  /// Il segnale è attivo.
  up,

  /// Qualcosa è cambiato sul Provider.
  changed,

  /// Il segnale è caduto: si torna al polling.
  down,
}

/// The single adapter interface (ADR 0002), one instance per Account.
// ponytail: Search joins the interface at step 6.
abstract interface class MailProvider() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Refreshes credentials; a definitive refusal is [AuthFailure].
  Future<Result<void>> refreshAuth();

  /// Headers of the last 90 days with Labels and Conversations, plus the inbox bodies.
  /// [onPage] gets each page as soon as it is fetched (newest first); the returned batch is still the whole
  /// snapshot, with the cursor: the caller saves the cursor only from it, so an interrupted run never skips messages.
  Future<Result<SyncBatch>> initialSync({SyncPage? onPage});

  /// Changes since [cursor]; an expired cursor is [NotFoundFailure], and the caller redoes the initial sync.
  Future<Result<SyncBatch>> incrementalSync(String cursor);

  /// "Something changed" signal (IMAP IDLE on the inbox); data comes from [incrementalSync].
  Stream<ChangeSignal> get changes;

  /// Scarica il corpo e i metadati degli allegati del messaggio `messageId`.
  Future<Result<MessageBody>> fetchBody(String messageId);

  /// Every message of the Conversazione, also those outside the sync window (Inviati, older than 90 days);
  /// headers only, bodies come from [fetchBody].
  Future<Result<List<Message>>> fetchConversation(String conversationId);

  /// Applies [action] to message [messageId] only if its attribute still has [expected] (the value it had here when
  /// the Azione was queued) or already the wanted one: [ActionApplied]; another value, changed elsewhere, writes
  /// nothing and is [ActionConflict]; a message gone is [ActionMessageGone]. [Delete] never conflicts, and a null
  /// [expected] forces the write («tieni la mia»). Adapters without a native conditional write read and compare first.
  Future<Result<ActionOutcome>> applyAction(String messageId, MailAction action, {Object? expected});

  /// One attachment of [messageId] ([Attachment.id]); [onProgress] gets the share downloaded so far (0–1),
  /// and completing [cancel] stops the download with [CancelledFailure].
  Future<Result<AttachmentBytes>> fetchAttachment(
    String messageId,
    String attachmentId, {
    void Function(double done)? onProgress,
    Future<void>? cancel,
  });

  /// Sends [raw] (the rendered RFC 5322 text, `renderMime`) whose Message-ID is [messageId].
  /// Idempotent on the Message-ID: a message already in Inviati is not sent again.
  /// [threadId] ([OutgoingMessage.conversationId]) keeps a reply in its Conversazione.
  /// [Ok] carries the Provider's id of the sent message.
  /// [submitted] (#175): the Provider already accepted the submission in an earlier attempt, only what follows it
  /// is left; [onSubmitted] tells the caller the moment it does, so it can remember it across a restart.
  Future<Result<String>> send(
    String messageId,
    String raw, {
    String? threadId,
    bool submitted = false,
    Future<void> Function()? onSubmitted,
  });

  /// [isNew]: creates the Bozza on the Provider; otherwise updates the one with [OutgoingMessage.messageId],
  /// [NotFoundFailure] if it is gone (deleted or sent elsewhere). With [expected] (the `DraftContent.fingerprint` of
  /// the version the Provider had at the last upload or sync, #149) the update is conditional: written only if the
  /// Provider still has that version or already [draft]'s, otherwise nothing is written and it is [DraftDiverged].
  Future<Result<DraftOutcome>> saveDraft(OutgoingMessage draft, {required bool isNew, String? expected});

  /// Elimina dal Provider la Bozza con Message-ID `messageId`.
  Future<Result<void>> deleteDraft(String messageId);

  /// Creates the Etichetta [name]; idempotent on the name: one that already exists is returned, not duplicated.
  Future<Result<Label>> createLabel(String name);
}
