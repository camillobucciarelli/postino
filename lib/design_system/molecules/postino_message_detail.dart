import '../atoms/postino_account_mark.dart';

/// One row of the details of a message (“Da”, “A”, “Data”, “Ricevuto su”); [account] puts its mark before [value].
class const PostinoMessageDetail(this.label, this.value, {this.account}) {
  /// Crea una riga di dettaglio.
  this;

  /// Nome del dato («Da», «A», «Data»).
  final String label;

  /// Il dato stesso.
  final String value;

  /// Account il cui segno precede il valore, se serve.
  final PostinoAccountRef? account;
}
