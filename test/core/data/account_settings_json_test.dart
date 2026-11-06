// The Accounts in the Impostazioni di Postino (#142, ADR 0016): their JSON voce, readable whatever wrote it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/domain/account.dart';

void main() {
  const ada = Account(
    id: 'gmail:ada@gmail.com',
    address: 'ada@gmail.com',
    provider: ProviderKind.gmail,
    color: 3,
    position: 2,
  );

  test('round trip keeps address, Provider, color and position; the status stays out, read as da ricollegare', () {
    final json = encodeAccountSettings(ada);
    expect(jsonDecode(json), {'address': 'ada@gmail.com', 'provider': 'gmail', 'color': 3, 'position': 2});
    final back = decodeAccountSettings(ada.id, json)!;
    expect(sameAccountSettings(back, ada), isTrue);
    expect(back.status, AccountStatus.daRicollegare);
  });

  test('a malformed voce, or one with an unknown Provider, is ignored', () {
    for (final json in [
      null,
      '',
      'not json',
      '[]',
      '{"address":"a@b.c","provider":"gmail","color":1}',
      '{"address":"","provider":"gmail","color":1,"position":0}',
      '{"address":"a@b.c","provider":"fastmail","color":1,"position":0}',
      '{"address":"a@b.c","provider":"gmail","color":"1","position":0}',
    ]) {
      expect(decodeAccountSettings('x', json), isNull, reason: '$json');
    }
  });

  test('unknown fields are ignored and a color outside the palette wraps into it', () {
    final a = decodeAccountSettings(
      'gmail:a@b.c',
      '{"address":"a@b.c","provider":"gmail","color":${accountColorCount + 1},"position":4,"name":"Ada"}',
    );
    expect((a!.color, a.position), (1, 4));
  });

  test('the voci of iCloud and IMAP Accounts decode, with their accountIdOf', () {
    for (final p in [ProviderKind.icloud, ProviderKind.imap]) {
      final a = Account(id: accountIdOf(p, 'ada@x.org'), address: 'ada@x.org', provider: p, color: 1, position: 3);
      expect(sameAccountSettings(decodeAccountSettings(a.id, encodeAccountSettings(a))!, a), isTrue, reason: p.name);
    }
  });

  test('a voce whose id is not provider:address is ignored; the address is normalized as connecting does', () {
    const json = '{"address":" A@B.c ","provider":"gmail","color":1,"position":0}';
    expect(decodeAccountSettings('gmail:a@b.c', json)?.address, 'a@b.c');
    for (final id in ['gmail:z@b.c', 'microsoft:a@b.c', 'a@b.c']) {
      expect(decodeAccountSettings(id, json), isNull, reason: id);
    }
  });
}
