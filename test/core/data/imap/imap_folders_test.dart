// Folders as Etichette: SPECIAL-USE (RFC 6154), the known names as fallback (iCloud), the rest as the user's.
import 'package:enough_mail/enough_mail.dart' show Mailbox, MailboxFlag;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_folders.dart';
import 'package:postino/core/domain/message.dart';

Mailbox _box(String path, [List<MailboxFlag> flags = const []]) =>
    Mailbox(encodedName: path.split('/').last, encodedPath: path, flags: [...flags], pathSeparator: '/');

Map<String, (String, bool)> _ids(List<Mailbox> boxes) => {
  for (final f in imapFolders(boxes)) f.path: (f.labelId, f.synced),
};

void main() {
  test('SPECIAL-USE folders get the system ids; the others are cartelle of the user, by full path', () {
    final folders = imapFolders([
      _box('INBOX'),
      _box('Posta inviata', [MailboxFlag.sent]),
      _box('Bozze', [MailboxFlag.drafts]),
      _box('Cestino', [MailboxFlag.trash]),
      _box('Spam', [MailboxFlag.junk]),
      _box('Archivio', [MailboxFlag.archive]),
      _box('Viaggi'),
      _box('Viaggi/2026/Estate'),
    ]);
    expect(
      {for (final f in folders) f.path: f.labelId},
      {
        'INBOX': inboxLabelId,
        'Posta inviata': sentLabelId,
        'Bozze': draftLabelId,
        'Cestino': trashLabelId,
        'Spam': 'Spam',
        'Archivio': 'Archivio',
        'Viaggi': 'Viaggi',
        'Viaggi/2026/Estate': 'Viaggi/2026/Estate',
      },
    );
    expect(
      [for (final f in folders) ?f.label],
      [
        const Label(id: 'Archivio', name: 'Archivio', kind: LabelKind.cartella),
        const Label(id: 'Viaggi', name: 'Viaggi', kind: LabelKind.cartella),
        const Label(id: 'Viaggi/2026/Estate', name: 'Viaggi/2026/Estate', kind: LabelKind.cartella),
      ],
    );
    expect(folders.where((f) => !f.synced).map((f) => f.path), ['Spam']);
  });

  test("without SPECIAL-USE, iCloud's names are the special folders", () {
    expect(
      _ids([
        _box('INBOX'),
        _box('Sent Messages'),
        _box('Deleted Messages'),
        _box('Drafts'),
        _box('Junk'),
        _box('Archive'),
        _box('Notes'),
      ]),
      {
        'INBOX': (inboxLabelId, true),
        'Sent Messages': (sentLabelId, true),
        'Deleted Messages': (trashLabelId, true),
        'Drafts': (draftLabelId, true),
        'Junk': ('Junk', false),
        'Archive': ('Archive', true),
        'Notes': ('Notes', true),
      },
    );
  });

  test('a known name stays the user\'s when SPECIAL-USE already gave that role to another folder', () {
    expect(
      _ids([
        _box('INBOX'),
        _box('Inviati', [MailboxFlag.sent]),
        _box('Sent'),
      ])['Sent'],
      ('Sent', true),
    );
  });

  test('unselectable folders and the virtual ones holding copies are left out', () {
    expect(
      _ids([
        _box('INBOX'),
        _box('[Gmail]', [MailboxFlag.noSelect]),
        _box('[Gmail]/All Mail', [MailboxFlag.all]),
        _box('[Gmail]/Starred', [MailboxFlag.flagged]),
      ]).keys,
      ['INBOX'],
    );
  });
}
