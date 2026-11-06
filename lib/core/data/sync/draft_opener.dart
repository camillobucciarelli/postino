import '../../domain/account.dart';
import '../../domain/html_text.dart';
import '../../domain/mail_provider.dart';
import '../../domain/message.dart';
import '../../domain/outbox_repository.dart';
import '../../domain/result.dart';
import '../mail_store.dart';

/// The Bozza to resume (#35): the local copy, or the Provider's when it is newer and nothing here waits to go.
class DraftOpener(final MailStore _store, final OutboxRepository _outbox) {
  Future<Result<OutgoingMessage>> open(Account account, String messageId, MailProvider provider) async {
    // ponytail: no guard on a queued Message-ID; the Bozze list hides it (watchAll) and Inviati reopens through cancelSend.
    final accountId = account.id;
    final local = await _outbox.localDraft(accountId, messageId);
    final remote = await _outbox.remoteDraft(accountId, messageId);
    // The local copy, unless the Provider has a newer one and nothing here is waiting to go:
    // then it was edited elsewhere since, and the Provider's version is taken over.
    // ponytail: by the device clock against the Provider's date; a clock far ahead keeps the local copy.
    // A reply created here always stays ours: the Provider dates it at upload time, after `updatedAt`,
    // and an edit elsewhere cannot be merged (it would drop In-Reply-To, thread or forwarded attachments),
    // so never refuse it.
    if (local != null &&
        (local.pending ||
            local.draft.inReplyTo != null ||
            local.draft.attachments.isNotEmpty ||
            remote == null ||
            remote.message.date.millisecondsSinceEpoch <= local.updatedAt)) {
      return Ok(local.draft);
    }
    if (remote == null) return const Err(NotFoundFailure());
    // A reply written elsewhere: the save would drop its In-Reply-To, References and thread.
    // ponytail: the local Bozze of #37 carry them; a remote one is still refused because its headers
    // are not fetched (metadata sync has no In-Reply-To): read them from the message when people ask.
    if (await _outbox.hasSiblings(accountId, remote.message.id)) {
      return const Err(DraftReplyFailure());
    }
    var body = remote.body;
    if (body == null) {
      switch (await provider.fetchBody(remote.message.id)) {
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
        BodyKind.testo => plainToHtml(body.content),
      },
    );
    // The Account removed while the body was downloading: no Bozza to open.
    if (!await _outbox.adoptDraft(accountId, draft, updatedAt: remote.message.date.millisecondsSinceEpoch)) {
      return const Err(NotFoundFailure());
    }
    return Ok(draft);
  }
}
