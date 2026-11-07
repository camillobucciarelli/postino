import 'package:enough_mail/enough_mail.dart' show ImapClient, MessageSequence, StoreAction;

import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_folders.dart';
import 'imap_session.dart';

/// Where a message is and what the server has of it: its folder and UID, `\Seen` and `\Flagged`, and the MODSEQ
/// when the server has CONDSTORE. Its folder is the selected one.
typedef ImapPlace = ({ImapFolder folder, int uidValidity, int uid, bool seen, bool flagged, int? modSeq});

const seenFlag = r'\Seen';
const flaggedFlag = r'\Flagged';

/// Selects [folder] and reads the flags of [uid] (one FETCH); null if the folder is gone, its UIDVALIDITY is not
/// [uidValidity] (when given) or the UID is no longer there.
Future<ImapPlace?> readPlace(
  ImapClient c,
  ImapFolder folder,
  int uid, {
  int? uidValidity,
  required bool condstore,
}) async {
  var validity = 0;
  try {
    final box = await selectFolder(c, folder.path, condstore: condstore);
    if (uidValidity != null && box.uidValidity != uidValidity) return null;
    validity = box.uidValidity ?? 0;
  } on ImapFailed catch (e) {
    if (e.failure is NotFoundFailure) return null;
    rethrow;
  }
  final r = await c.uidFetchMessages(
    MessageSequence.fromId(uid, isUid: true),
    condstore ? '(UID FLAGS MODSEQ)' : '(UID FLAGS)',
    responseTimeout: ImapSession.timeout,
  );
  final m = r.messages.where((m) => m.uid == uid).firstOrNull;
  if (m == null) return null;
  return (
    folder: folder,
    uidValidity: validity,
    uid: uid,
    seen: m.isSeen,
    flagged: m.isFlagged,
    modSeq: condstore ? m.modSequence : null,
  );
}

/// Adds or removes [flag] on [at]. With a MODSEQ the write is conditional (`UNCHANGEDSINCE`): false when the flags
/// changed since the read (`MODIFIED`), and the caller reads and compares again.
Future<bool> storeFlag(ImapClient c, ImapPlace at, String flag, {required bool add}) async {
  final r = await c.uidStore(
    at.modSeq == null ? MessageSequence.fromId(at.uid, isUid: true) : _Unchanged(at.uid, at.modSeq!),
    [flag],
    action: add ? StoreAction.add : StoreAction.remove,
  );
  return r.modifiedMessageSequence?.isEmpty ?? true;
}

/// A UID that renders with its modifier: `5 (UNCHANGEDSINCE 100)`. RFC 7162 §3.1.3 puts the modifier after the
/// sequence set, but enough_mail 3.0.0 writes `UID STORE (UNCHANGEDSINCE 100) 5` for `unchangedSinceModSequence`,
/// which servers refuse.
// ponytail: through the sequence set's rendering, the one hook the library leaves; drop it if enough_mail fixes the order.
class _Unchanged(final int _uid, final int _modSeq) extends MessageSequence {
  this : super(isUidSequence: true);

  @override
  void render(StringBuffer buffer) => buffer.write('$_uid (UNCHANGEDSINCE $_modSeq)');
}
