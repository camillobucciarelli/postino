import 'package:enough_mail/enough_mail.dart' show ImapClient, ImapException, Mailbox;

import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_folders.dart';

/// The folder [name] of the Account, created if missing (CREATE, idempotent on the name): a folder already there
/// is returned. [boxes] lists every folder.
Future<ImapFolder> ensureFolder(ImapClient c, String name, Future<List<Mailbox>> Function() boxes) async {
  Future<ImapFolder?> find() async =>
      imapFolders(await boxes()).where((f) => f.path == name || f.labelId == name).firstOrNull;
  if (await find() case final f?) return f;
  try {
    await c.createMailbox(name);
  } on ImapException {
    // A CREATE raced by another client, or enough_mail not finding the folder it just created: there it is.
    if (!c.isConnected) rethrow;
  }
  return await find() ?? (throw ImapFailed(RejectedFailure('the server refused the folder $name')));
}
