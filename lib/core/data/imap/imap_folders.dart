import 'package:enough_mail/enough_mail.dart' show Mailbox, MailboxFlag;

import '../../domain/message.dart';

/// What a folder is for: the special ones (RFC 6154 SPECIAL-USE, or a well-known name) and the user's own.
enum FolderRole() {
  inbox,
  sent,
  drafts,
  trash,
  junk,
  archive,
  user,
}

/// The Etichetta id of the user's folder [path]: in a namespace of its own, so a folder named `DRAFT` or
/// `STARRED` is not taken for a system label.
String folderLabelId(String path) => '$_folderPrefix$path';

/// The folder path of an Etichetta id made by [folderLabelId]; null for any other id.
String? folderPathOf(String labelId) =>
    labelId.startsWith(_folderPrefix) ? labelId.substring(_folderPrefix.length) : null;

const _folderPrefix = 'cartella:';

/// A folder of the Account: its [path] on the server (decoded), its [role], and the Etichetta id its messages carry:
/// the system id (`INBOX`, `SENT`, `DRAFT`, `TRASH`) for the special ones, else [folderLabelId].
class const ImapFolder(final String path, final FolderRole role) {
  String get labelId => switch (role) {
    FolderRole.inbox => inboxLabelId,
    FolderRole.sent => sentLabelId,
    FolderRole.drafts => draftLabelId,
    FolderRole.trash => trashLabelId,
    _ => folderLabelId(path),
  };

  /// Junk is neither synced nor shown.
  // ponytail: no Spam view in v1; sync Junk with a SPAM label when one exists.
  bool get synced => role != FolderRole.junk;

  /// An Etichetta of the user (Archive too: it has no system id): a [LabelKind.cartella] named by its full path,
  /// so a folder nested deeper than the first level shows where it sits.
  Label? get label => role == FolderRole.user || role == FolderRole.archive
      ? Label(id: labelId, name: path, kind: LabelKind.cartella)
      : null;
}

/// Names that mean a special folder on servers without SPECIAL-USE (iCloud's among them), lowercase.
const _knownNames = {
  FolderRole.sent: {'sent', 'sent messages', 'sent items', 'sent mail', 'inviati', 'posta inviata'},
  FolderRole.drafts: {'drafts', 'bozze'},
  FolderRole.trash: {'trash', 'deleted messages', 'deleted items', 'cestino'},
  FolderRole.junk: {'junk', 'spam', 'junk e-mail', 'posta indesiderata'},
  FolderRole.archive: {'archive', 'archivio'},
};

/// The folders of a LIST: SPECIAL-USE first; a role nobody announces goes to the first folder with a known name.
/// Unselectable folders and the virtual ones holding copies (`\All`, `\Flagged`) are left out: they would sync
/// every message twice.
List<ImapFolder> imapFolders(List<Mailbox> boxes) {
  final selectable = [
    for (final b in boxes)
      if (!b.isNotSelectable &&
          !b.hasFlag(MailboxFlag.nonExistent) &&
          !b.hasFlag(MailboxFlag.all) &&
          !b.hasFlag(MailboxFlag.flagged))
        b,
  ];
  final roles = <String, FolderRole>{for (final b in selectable) b.path: _specialUse(b) ?? FolderRole.user};
  for (final MapEntry(key: role, value: names) in _knownNames.entries) {
    if (roles.containsValue(role)) continue;
    for (final b in selectable) {
      if (roles[b.path] == FolderRole.user && names.contains(b.path.toLowerCase())) {
        roles[b.path] = role;
        break;
      }
    }
  }
  return [for (final MapEntry(:key, :value) in roles.entries) ImapFolder(key, value)];
}

FolderRole? _specialUse(Mailbox b) => b.isInbox
    ? FolderRole.inbox
    : b.isSent
    ? FolderRole.sent
    : b.isDrafts
    ? FolderRole.drafts
    : b.isTrash
    ? FolderRole.trash
    : b.isJunk
    ? FolderRole.junk
    : b.isArchive
    ? FolderRole.archive
    : null;
