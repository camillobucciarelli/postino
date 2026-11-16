// The closed list of synced Impostazioni di Postino (#124, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/synced_settings.dart';

void main() {
  test('only the closed list syncs', () {
    expect(isSyncedSetting('auto_labels/a1'), isTrue);
    expect(isSyncedSetting('accounts/a1'), isTrue);
    expect(isSyncedSetting('swipe/left'), isTrue);
    expect(isSyncedSetting('sidebar_expanded'), isFalse);
    // swipe/ is not per Account: removing an Account writes no tombstone for it.
    expect(accountSettingKeys('a1'), ['auto_labels/a1', 'accounts/a1']);
  });

  test('the credentials of iCloud and IMAP sync, and the OAuth ones of each client (#321)', () {
    expect(isSyncedSetting('credentials/icloud:ada@icloud.com'), isTrue);
    expect(isSyncedSetting('credentials/imap:ada@example.com'), isTrue);
    expect(isSyncedSetting('credentials/gmail:ada@gmail.com/c1'), isTrue);
    expect(isSyncedSetting('credentials/microsoft:ada@outlook.com/c1'), isTrue);
    // Without a client it is no voce this Postino knows: it stays in the file only.
    expect(isSyncedSetting('credentials/gmail:ada@gmail.com'), isFalse);
    expect(isOAuthCredentialSetting('credentials/imap:ada@example.com'), isFalse);
    expect(isCredentialSetting('credentials/microsoft:ada@outlook.com/c1'), isTrue);
    expect(credentialAccountId('credentials/gmail:a/b@gmail.com/c1'), 'gmail:a/b@gmail.com');
    expect(credentialAccountId('credentials/imap:ada@example.com'), 'imap:ada@example.com');
    expect(isPasswordCredentialSetting('credentials/imap:ada@example.com'), isTrue);
    expect(isPasswordCredentialSetting('accounts/imap:ada@example.com'), isFalse);
    // Removing a password Account tombstones its credentials too.
    expect(accountSettingKeys('imap:ada@example.com'), [
      'auto_labels/imap:ada@example.com',
      'accounts/imap:ada@example.com',
      'credentials/imap:ada@example.com',
    ]);
    expect(accountSettingKeys('gmail:ada@gmail.com'), [
      'auto_labels/gmail:ada@gmail.com',
      'accounts/gmail:ada@gmail.com',
    ]);
  });
}
