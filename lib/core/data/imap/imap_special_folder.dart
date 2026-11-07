import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException, ReturnOption;

import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_folder_sync.dart';
import 'imap_folders.dart';
import 'imap_session.dart';

/// The folder with [role] (Inviati, Bozze), created as [name] when the server has none: GreenMail starts with
/// INBOX only, and a new folder with a known name takes the role ([imapFolders]).
// ponytail: a LIST per call; remember the path in the session if sends and Bozze get slow.
Future<ImapFolder> specialFolder(ImapClient c, ImapSession s, FolderRole role, String name) async {
  Future<ImapFolder?> find() async => imapFolders(
    await c.listMailboxes(recursive: true, returnOptions: s.specialUse ? [ReturnOption.specialUse()] : null),
  ).where((f) => f.role == role).firstOrNull;
  if (await find() case final f?) return f;
  try {
    await c.createMailbox(name);
  } on ImapException {
    // A CREATE raced by another client, or enough_mail not finding the folder it just created: there it is.
    if (!c.isConnected) rethrow;
  }
  return await find() ?? (throw ImapFailed(RejectedFailure('the server refused the folder $name')));
}

/// The UIDs of the messages with Message-ID [messageId] in the selected folder, oldest first; none for an id a
/// quoted SEARCH string cannot carry (empty, not ASCII).
Future<List<int>> uidsOfMessageId(ImapClient c, String messageId) async {
  if (!RegExp(r'^[\x20-\x7e]+$').hasMatch(messageId)) return const [];
  final quoted = '"${messageId.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  return (await search(c, 'HEADER Message-ID $quoted'))..sort();
}
