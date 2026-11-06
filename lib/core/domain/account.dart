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
  imap;

  /// Whether an Etichetta is a folder: applying one moves the message, so it offers Annulla like Archivia (#146).
  bool get labelsAreFolders => this != gmail;
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
  /// Id locale stabile dell'Account.
  required final String id,

  /// Indirizzo email dell'Account.
  required final String address,

  /// Il Provider che ospita l'Account.
  required final ProviderKind provider,

  /// Position in the palette of [accountColorCount] Account colors; the theme gives the actual color.
  required final int color,

  /// Ordine di visualizzazione tra gli Account.
  required final int position,

  /// Se l'Account funziona o va ricollegato.
  final AccountStatus status = AccountStatus.attivo,
}) extends Equatable {
  /// Crea un Account; `status` parte da `attivo`.
  this;

  // ponytail: no name nor chosen initial in the domain yet, both come from the address.
  /// Nome mostrato: per ora coincide con l'indirizzo.
  String get name => address;

  /// Iniziale maiuscola dell'indirizzo, `?` se vuoto.
  String get initial => address.isEmpty ? '?' : address[0].toUpperCase();

  @override
  List<Object?> get props => [id, address, provider, color, position, status];
}

/// An address as Postino keeps it: trimmed and lowercase, as mail addresses are case-insensitive.
String normalizedAddress(String address) => address.trim().toLowerCase();

// ponytail: id = provider:address, so the same mailbox is the same Account; a separate uuid if addresses ever change.
/// The id of the Account at [address] on [provider].
String accountIdOf(ProviderKind provider, String address) => '${provider.name}:${normalizedAddress(address)}';

/// Colors of the Account palette, assigned in turn to new Accounts.
const accountColorCount = 8;
