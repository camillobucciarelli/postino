import 'package:enough_mail/enough_mail.dart' show ImapClient, Mailbox, ReturnOption;

import 'imap_folder_create.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_session.dart';

/// A special folder selected, with the UIDs of the messages holding one Message-ID, oldest first.
typedef SpecialSelection = ({ImapFolder folder, int uidValidity, List<int> uids});

/// Selects the folder with [role] (Inviati, Bozze), created as [name] when the server has none, and searches it
/// for [messageId].
Future<SpecialSelection> selectSpecial(
  ImapClient c,
  ImapSession s,
  FolderRole role,
  String name,
  String messageId,
) async {
  final folder = await _specialFolder(c, s, role, name);
  final box = await selectFolder(c, folder.path, condstore: s.condstore);
  return (folder: folder, uidValidity: box.uidValidity ?? 0, uids: await _uidsOf(c, messageId));
}

/// GreenMail starts with INBOX only, and a new folder with a known name takes the role ([imapFolders]).
// ponytail: a LIST per call; remember the path in the session if sends and Bozze get slow.
Future<ImapFolder> _specialFolder(ImapClient c, ImapSession s, FolderRole role, String name) async {
  Future<List<Mailbox>> boxes() =>
      c.listMailboxes(recursive: true, returnOptions: s.specialUse ? [ReturnOption.specialUse()] : null);
  return imapFolders(await boxes()).where((f) => f.role == role).firstOrNull ?? await ensureFolder(c, name, boxes);
}

/// The UIDs of the messages with Message-ID [messageId] in the selected folder, oldest first. Postino's
/// Message-IDs are ASCII (`newMessageId`); one a quoted SEARCH string cannot carry (from another client) finds none.
// ponytail: SEARCH HEADER matches case-insensitively, Message-IDs compare exactly; with 24 random characters a
// clash is out of reach, fetch and compare the headers if ids of other clients ever matter here.
Future<List<int>> _uidsOf(ImapClient c, String messageId) async {
  if (!RegExp(r'^[\x20-\x7e]+$').hasMatch(messageId)) return const [];
  final quoted = '"${messageId.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  return (await search(c, 'HEADER Message-ID $quoted'))..sort();
}
