import 'dart:convert';

import '../domain/account.dart';

/// The key of the voce of [accountId] in the Impostazioni di Postino.
String accountSettingsKey(String accountId) => 'accounts/$accountId';

/// The Account as its JSON voce of the Impostazioni di Postino (ADR 0016):
/// `{"address":"…","provider":"gmail","color":<palette index>,"position":<int>}`.
/// Never the status nor a credential: both stay on the device.
String encodeAccountSettings(Account a) =>
    jsonEncode({'address': a.address, 'provider': a.provider.name, 'color': a.color, 'position': a.position});

/// The Account [accountId] of the voce [json], da ricollegare until it is connected here. Reading is lenient:
/// a malformed voce, or one with a Provider this Postino does not know, is null and is ignored; unknown fields
/// are ignored, for voci written by a newer version; a color outside the palette wraps into it.
Account? decodeAccountSettings(String accountId, String? json) {
  final Object? root;
  try {
    root = json == null ? null : jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (root is! Map<String, dynamic>) return null;
  final name = root['provider'];
  final provider = ProviderKind.values.where((p) => p.name == name).firstOrNull;
  return switch ((root['address'], root['color'], root['position'])) {
    (final String address, final int color, final int position) when provider != null && address.isNotEmpty => Account(
      id: accountId,
      address: address,
      provider: provider,
      color: color % accountColorCount,
      position: position,
      status: AccountStatus.daRicollegare,
    ),
    _ => null,
  };
}

/// Whether [a] and [b] say the same in the voce: address, Provider, color and position (not the status).
bool sameAccountSettings(Account a, Account b) =>
    a.address == b.address && a.provider == b.provider && a.color == b.color && a.position == b.position;
