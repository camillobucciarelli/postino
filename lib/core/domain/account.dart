enum ProviderKind { gmail, microsoft, icloud, imap }

enum AccountStatus { attivo, daRicollegare }

class Account {
  const Account({
    required this.id,
    required this.address,
    required this.provider,
    required this.color,
    required this.position,
    this.status = AccountStatus.attivo,
  });

  final String id;
  final String address;
  final ProviderKind provider;

  /// ARGB value; `dart:ui` Color is not available in the pure-Dart domain.
  final int color;
  final int position;
  final AccountStatus status;
}
