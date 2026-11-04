import 'package:equatable/equatable.dart';

enum ProviderKind { gmail, microsoft, icloud, imap }

enum AccountStatus { attivo, daRicollegare }

class Account extends Equatable {
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

  /// Position in the palette of [accountColorCount] Account colors; the theme gives the actual color.
  final int color;
  final int position;
  final AccountStatus status;

  // ponytail: no name nor chosen initial in the domain yet, both come from the address.
  String get name => address;
  String get initial => address.isEmpty ? '?' : address[0].toUpperCase();

  @override
  List<Object?> get props => [id, address, provider, color, position, status];
}

/// Colors of the Account palette, assigned in turn to new Accounts.
const accountColorCount = 8;
