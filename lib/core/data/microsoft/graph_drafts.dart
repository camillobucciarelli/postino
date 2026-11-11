import 'dart:convert';

import '../../domain/draft_content.dart';
import '../../domain/draft_outcome.dart';
import '../../domain/html_text.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';
import 'graph_bodies.dart';
import 'graph_http.dart';
import 'graph_lookup.dart';
import 'graph_message_parser.dart';

/// Bozze on Graph (#183): a message made from MIME cannot be edited, so every save creates the new version
/// (`POST /me/messages`, MIME as base64) and removes the previous one, found by its Message-ID, which stays while
/// Graph's id changes. Same scheme as IMAP (#166). Failures are thrown as [OAuthFailed].
class GraphDrafts(final GraphHttp _graph, final GraphLookup _lookup) {
  static const _folder = 'drafts';

  /// Uploads [raw], the MIME of [draft]. [isNew] creates it (a copy already there, a save whose answer was lost,
  /// is replaced); otherwise the Bozza must be there, else [NotFoundFailure] (deleted or sent elsewhere). With
  /// [expected] (#149) the Bozza on Graph is read first: neither that impronta nor [draft]'s is [DraftDiverged],
  /// and nothing is written.
  Future<DraftOutcome> save(OutgoingMessage draft, String raw, {required bool isNew, String? expected}) async {
    final old = await _lookup.idsIn(_folder, draft.messageId);
    if (old.isEmpty && !isNew) throw const OAuthFailed(NotFoundFailure());
    if (old.isNotEmpty && !isNew && expected != null) {
      // A half-finished save leaves two copies, and Graph's order is unspecified: diverged only if none of them is
      // what was expected or what is being saved.
      final mine = DraftContent.of(draft).fingerprint;
      DraftContent? last;
      for (final id in old) {
        last = await _content(id);
        if (last.fingerprint == expected || last.fingerprint == mine) {
          last = null;
          break;
        }
      }
      if (last != null) return DraftDiverged(last);
    }
    await _graph.send('POST', 'messages', text: base64.encode(utf8.encode(raw)));
    // Created first: a failure in between leaves two copies, never none; the next save removes the older.
    // Only a copy whose impronta is known (what was expected, what was just saved) is purged. Any other copy with
    // this Message-ID was edited elsewhere: it goes to Posta eliminata, recoverable, and is no conflict, so a
    // half-finished save's older leftover never reads as a false DraftDiverged.
    final known = {DraftContent.of(draft).fingerprint, ?expected};
    for (final id in old) {
      try {
        await (known.contains((await _content(id)).fingerprint) ? _purge(id) : _trash(id));
      } on OAuthFailed catch (e) {
        // Gone in the meantime: what was wanted.
        if (e.failure is! NotFoundFailure) rethrow;
      }
    }
    return const DraftSaved();
  }

  /// Removes the Bozza with [messageId]; [NotFoundFailure] when there is none (already deleted, or sent).
  Future<void> delete(String messageId) async {
    final ids = await _lookup.idsIn(_folder, messageId);
    if (ids.isEmpty) throw const OAuthFailed(NotFoundFailure());
    await _remove(ids);
  }

  /// The Bozza the user or the send removes: gone for good, not into Posta eliminata (a Bozza saved at every pause
  /// would fill it).
  Future<void> _remove(List<String> ids) async {
    for (final id in ids) {
      try {
        await _purge(id);
      } on OAuthFailed catch (e) {
        // Already gone, deleted elsewhere in the meantime: what was wanted.
        if (e.failure is! NotFoundFailure) rethrow;
      }
    }
  }

  /// `permanentDelete`; where Graph does not offer it (404, 405, 501) the ordinary DELETE, which keeps the copy in
  /// Posta eliminata: recoverable rather than lost.
  Future<void> _purge(String id) async {
    try {
      await _graph.send('POST', 'messages/$id/permanentDelete');
    } on OAuthFailed catch (e) {
      final f = e.failure;
      final missing = f is NotFoundFailure || (f is UnexpectedFailure && RegExp('HTTP (405|501)').hasMatch('$f'));
      if (!missing) rethrow;
      await _trash(id);
    }
  }

  /// DELETE: into Posta eliminata, where it can be recovered.
  Future<void> _trash(String id) async {
    await _graph.send('DELETE', 'messages/$id');
  }

  /// The Bozza [id] as Graph has it: what its impronta compares. A plain text body is taken as HTML, as when the
  /// Bozza is opened here.
  Future<DraftContent> _content(String id) async {
    final j = await _graph.get('messages/$id', query: {r'$select': graphBodySelect}, prefer: GraphBodies.html);
    final m = parseGraphMessage(j, labelId: draftLabelId);
    final body = graphBody(j) ?? const MessageBody('', BodyKind.testo);
    return DraftContent(
      to: m.to,
      cc: m.cc,
      bcc: m.bcc,
      subject: m.subject,
      body: body.kind == BodyKind.html ? body.content : plainToHtml(body.content),
    );
  }
}
