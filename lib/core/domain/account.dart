import 'package:equatable/equatable.dart';

/// Il servizio che ospita la posta di un Account.
enum ProviderKind() {
  /// Gmail (Google).
  gmail,

  /// Microsoft (Outlook, Exchange Online).
  microsoft,

  /// iCloud Mail.
  icloud,

  /// Server IMAP generico.
  imap,
}

/// Stato di collegamento di un Account.
enum AccountStatus() {
  /// Le credenziali funzionano e la sincronizzazione va.
  attivo,

  /// Il Provider ha rifiutato le credenziali: serve un nuovo consenso.
  daRicollegare,
}

/// Una casella di posta collegata a Postino.
class const Account({
  required this.id,
  required this.address,
  required this.provider,
  required this.color,
  required this.position,
  this.status = AccountStatus.attivo,
}) extends Equatable {
  /// Crea un Account; `status` parte da `attivo`.
  this;

  /// Id locale stabile dell'Account.
  final String id;

  /// Indirizzo email dell'Account.
  final String address;

  /// Il Provider che ospita l'Account.
  final ProviderKind provider;

  /// Position in the palette of [accountColorCount] Account colors; the theme gives the actual color.
  final int color;

  /// Ordine di visualizzazione tra gli Account.
  final int position;

  /// Se l'Account funziona o va ricollegato.
  final AccountStatus status;

  // ponytail: no name nor chosen initial in the domain yet, both come from the address.
  /// Nome mostrato: per ora coincide con l'indirizzo.
  String get name => address;

  /// Iniziale maiuscola dell'indirizzo, `?` se vuoto.
  String get initial => address.isEmpty ? '?' : address[0].toUpperCase();

  @override
  List<Object?> get props => [id, address, provider, color, position, status];
}

/// Colors of the Account palette, assigned in turn to new Accounts.
const accountColorCount = 8;
