// A consent here writes the voce of this device's OAuth client, so the other devices get the Account (ADR 0019, #321).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/accounts_service.dart';
import 'package:postino/core/data/oauth/oauth_voce.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/credential_voci.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

const _id = 'gmail:ada@gmail.com';

AccountsService _service() => AccountsService(
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  getIt(),
  oauthClientOf: (p) => p == ProviderKind.icloud ? '' : 'client-${p.name}',
);

Future<String?> _voce(String id, ProviderKind p) =>
    getIt<PostinoDatabase>().postinoSettingsDao.read(oauthCredentialsKey(id, 'client-${p.name}'));

void main() {
  test('connecting Gmail writes the voce of its client; granting Drive writes it again with the Drive scope', () async {
    final h = await Harness.create();
    h.providerFor(_id);
    final service = _service();

    await service.connectGmail();
    const mail = ['https://mail.google.com/', 'openid'];
    expect(
      await _voce(_id, ProviderKind.gmail),
      credentialFingerprint(const OAuthVoce(refresh: 'refresh-token-1', scopes: mail).encode()),
    );

    await service.grantDriveAccess(_id);
    expect(
      await _voce(_id, ProviderKind.gmail),
      credentialFingerprint(
        const OAuthVoce(
          refresh: 'refresh-token-2',
          scopes: [...mail, 'https://www.googleapis.com/auth/drive.appdata'],
        ).encode(),
      ),
    );
  });

  test('connecting Microsoft writes the voce of its client', () async {
    final h = await Harness.create();
    h.providerFor('microsoft:ada@outlook.com');
    await _service().connectMicrosoft();
    expect(await _voce('microsoft:ada@outlook.com', ProviderKind.microsoft), isNotNull);
  });
}
