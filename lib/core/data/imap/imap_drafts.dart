import 'package:enough_mail/enough_mail.dart' show ImapClient, MessageFlags, MessageSequence;

import '../../domain/draft_content.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/html_text.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_session.dart';
import 'imap_special_folder.dart';

/// Bozze on IMAP (#166): no update in the protocol, so every save APPENDs the new version (`\Draft`) to the Bozze
/// folder and removes the previous one, found by its Message-ID, which stays while the UID changes at every save.
class ImapDrafts(final ImapSession _session) {
  /// Uploads [raw], the MIME of [draft]. [isNew] creates it (a copy already there, a save whose answer was lost,
  /// is replaced); otherwise the Bozza must be there, else [NotFoundFailure] (deleted or sent elsewhere). With
  /// [expected] (#149) the Bozza on the server is read first: neither that impronta nor [draft]'s is
  /// [DraftDiverged], and nothing is written.
  Future<DraftOutcome> save(OutgoingMessage draft, String raw, {required bool isNew, String? expected}) =>
      _session.run((c) async {
        final (:folder, :uidValidity, uids: old) = await _select(c, draft.messageId);
        if (old.isEmpty && !isNew) throw const ImapFailed(NotFoundFailure());
        if (old.isNotEmpty && !isNew && expected != null) {
          final current = await _content(c, folder, uidValidity, old.last);
          final fingerprint = current.fingerprint;
          if (fingerprint != expected && fingerprint != DraftContent.of(draft).fingerprint) {
            return DraftDiverged(current);
          }
        }
        await c.appendMessageText(
          raw,
          targetMailboxPath: folder.path,
          flags: [MessageFlags.draft, MessageFlags.seen],
          responseTimeout: ImapSession.timeout,
        );
        // APPEND first: a failure in between leaves two copies, never none; the next save removes the older.
        if (old.isNotEmpty) await _expunge(c, old);
        return const DraftSaved();
      });

  /// Removes the Bozza with [messageId]; [NotFoundFailure] when there is none (already deleted, or sent).
  Future<void> delete(String messageId) => _session.run((c) async {
    final uids = (await _select(c, messageId)).uids;
    if (uids.isEmpty) throw const ImapFailed(NotFoundFailure());
    await _expunge(c, uids);
  });

  Future<SpecialSelection> _select(ImapClient c, String messageId) =>
      selectSpecial(c, _session, FolderRole.drafts, 'Drafts', messageId);

  /// `\Deleted` and `UID EXPUNGE` of [uids] in the selected folder.
  Future<void> _expunge(ImapClient c, List<int> uids) async {
    final sequence = MessageSequence.fromIds(uids, isUid: true);
    await c.uidMarkDeleted(sequence, silent: true);
    // ponytail: without UIDPLUS a plain EXPUNGE also removes what another client marked \Deleted in Bozze and did
    // not expunge yet; a server lacking UIDPLUS today is rare.
    _session.uidplus ? await c.uidExpunge(sequence) : await c.expunge();
  }

  /// The Bozza [uid] as the server has it: what its impronta compares. A plain text body is taken as HTML, as when
  /// the Bozza is opened here.
  static Future<DraftContent> _content(ImapClient c, ImapFolder f, int uidValidity, int uid) async {
    final parsed = (await fetchMessages(c, f, uidValidity, [uid], withBody: true)).firstOrNull;
    if (parsed == null) throw const ImapFailed(NotFoundFailure());
    final m = parsed.message;
    final body = parsed.body!;
    return DraftContent(
      to: m.to,
      cc: m.cc,
      bcc: m.bcc,
      subject: m.subject,
      body: body.kind == BodyKind.html ? body.content : plainToHtml(body.content),
    );
  }
}
